# Builder API

AI generation, accounts and credits in AnyMetrics talk to the **Builder API**. The server is not part of this repository. This document describes the contract the iOS client expects, so a fork can run its own server.

Widgets and metrics do not use the Builder API. They work without it.

The source of truth is [`APIClient.swift`](../AnyMetrics/Service/API/APIClient.swift) and [`BuilderAPI.swift`](../AnyMetrics/Service/API/BuilderAPI.swift). If this document and the code disagree, the code wins.

## Server address

| Build | Server |
|---|---|
| Release | `BUILDER_API_URL`, or `http://127.0.0.1:3000` when it is empty |
| Debug | Same default. The Dev Menu on the info screen can switch to local or any custom URL |

Set the address when generating the project:

```bash
TUIST_BUILDER_API_URL=https://api.example.com tuist generate
```

Release builds ignore a server picked in the Dev Menu by an earlier debug build.

## Conventions

- JSON in and out. Requests send `Accept: application/json`; requests with a body send `Content-Type: application/json`. `null` fields are dropped from request bodies.
- Dates are ISO 8601, with or without fractional seconds.
- Signed-in calls send `Authorization: Bearer <token>`. The token is opaque to the client.
- A `401` drops the stored session for the current server only.
- Each server keeps its own session. Switching servers does not sign out of the others.

### Errors

Any non-success status may carry a body:

```json
{ "error": { "code": "PAYMENT_REQUIRED", "message": "No credits left.", "balance": 0, "required": 1 } }
```

`message` is shown to the user as is. `code`, `balance` and `required` are optional. A Fastify-style `{ "message": "..." }` body is also understood.

Codes the client acts on:

| Status / code | Client behavior |
|---|---|
| `401` | Clears the session, shows sign-in |
| `ACCOUNT_DELETED` on sign-in | Shows the server message; no token is stored |
| `PAYMENT_REQUIRED` on generate | Opens the top-up screen, then retries the prompt after a purchase |

## Endpoints

### Health and sign-in

| Method | Path | Auth | Success | Body → Response |
|---|---|---|---|---|
| `GET` | `/health` | — | `200` | → `{ "status": "ok" }` |
| `GET` | `/v1/auth/providers` | — | `200` | → `{ "providers": ["apple", "google", "github"] }` |
| `POST` | `/v1/auth/apple` | — | `200` | `{ identityToken, nonce?, name? }` → Session |
| `POST` | `/v1/auth/google` | — | `200` | `{ idToken }` → Session |
| `POST` | `/v1/auth/github` | — | `200` | `{ code, redirectUri? }` → Session |
| `POST` | `/v1/auth/logout` | Bearer | `204` | — |

The sign-in screen shows only the providers listed by `/v1/auth/providers`.

Google and GitHub use PKCE in the app; the server receives only the resulting ID token or authorization code. GitHub's client secret, if any, stays on the server.

Session:

```json
{ "token": "opaque", "user": { "id": "uuid", "email": "a@b.c", "name": "Ann" }, "balance": 3, "paid": false }
```

### Account

| Method | Path | Auth | Success | Response |
|---|---|---|---|---|
| `GET` | `/v1/me` | Bearer | `200` | `{ user, balance, paid }` |
| `DELETE` | `/v1/me` | Bearer | `204` | — |

`DELETE /v1/me` marks the account deleted and ends every session for it, on all devices. The client then drops the stored token for this server. The user, balance, payments and jobs stay in the server database until a later removal. A `401` means the token was already gone and nothing changed.

Signing in again with the same provider or the same verified email returns `401 ACCOUNT_DELETED` ("This account is deleted.") and no session.

`paid` is `false` while the balance is the free allowance. The app labels it "free attempts" until the first purchase.

### Credits

| Method | Path | Auth | Success | Body → Response |
|---|---|---|---|---|
| `GET` | `/v1/billing` | Bearer | `200` | → `{ balance, paid }` |
| `POST` | `/v1/billing/apple/transactions` | Bearer | `200` | `{ signedTransaction }` → `{ balance, credited, duplicate, productId, transactionId }` |

`signedTransaction` is the StoreKit 2 JWS. The purchase sets `appAccountToken` to the user `id`, so the server can match the transaction to the account. The server must treat a repeated transaction as `duplicate: true` without crediting again: the app resends unfinished transactions on launch.

Products and credits are listed in [`CreditProducts.swift`](../AnyMetrics/Service/Store/CreditProducts.swift) and must match the server.

### Generation

| Method | Path | Auth | Success | Body → Response |
|---|---|---|---|---|
| `POST` | `/v1/metrics/generate` | Bearer | `202` | `{ prompt, locale?, sourceUrl? }` → `{ jobId, status }` |
| `GET` | `/v1/jobs` | Bearer | `200` | → `{ jobs: [JobSummary] }` |
| `GET` | `/v1/jobs/{id}` | Bearer | `200` | → Job |
| `POST` | `/v1/jobs/{id}/answer` | Bearer | `202` | `{ text }` → `{ jobId, status }` |
| `POST` | `/v1/jobs/{id}/cancel` | Bearer | `200` | → `{ jobId, status }` |

- `generate` sends an `Idempotency-Key` header. A retried request with the same key must return the same job, not start and charge a second one.
- `?test=1` on `generate` starts a simulated job (Debug builds, Dev Menu). Jobs report it back as `simulation: true`.
- Job ids in paths are lowercase UUIDs.
- The client polls `GET /v1/jobs/{id}` once a second while the status is `queued` or `running`, backing off up to 15 seconds after errors.

Job statuses: `queued`, `running`, `needs_input`, `completed`, `failed`, `cancelled`.

Job (fields other than `jobId`, `status`, `prompt`, `createdAt` are optional):

| Field | Meaning |
|---|---|
| `dialog` | Questions asked so far, oldest first: `{ question, askedAt, answer?, answeredAt? }` |
| `question` | Open question while `needs_input`: `{ text, options?, allowsFreeText }` |
| `result` | On `completed`: `{ metric, validation, source }` |
| `draft` | Metric found but not yet validated: `{ metric, validated }` |
| `alternative` | A metric that needs something from the user: `{ reason, metric, requirement }` |
| `requirement` | What the user must supply: `{ kind: api_key / account / other, text, url? }` |
| `error` | On `failed`: an error object as above |

A generated `metric` has the same shape as a Gallery metric: `id`, `title`, `measure`, `type` (`json` / `web` / `checkStatus`), `resultKind` (`content` / `image`), `interval`, `request { url, method: GET / HEAD, headers }`, `formatter`, `rules`, and optional `author`, `description`, `website`.

## What leaves the device

Only the user's own input to generation reaches the server: the prompt, the locale, and answers to follow-up questions. Saved metrics — their URLs, headers, keys and values — are never sent. The client also has a `POST /v1/metrics/validate` call, but no screen uses it.
