# Privacy & analytics

**Your data stays on your device.**

- Metrics — URLs, headers, API keys, bodies, values — are stored locally in the app's private storage, shared only with the AnyMetrics widget. Nothing is synced to iCloud or sent to us.
- Requests go **directly** from your iPhone to your endpoint. There is no proxy or AnyMetrics server in between.
- When you share or export a metric, you choose whether to include the request. The app warns you that it may contain API keys.
- The Gallery list is downloaded from [GitHub](https://github.com/hudishkin/AnyMetricsGallery).

AnyMetrics also sends **anonymous usage events** (Google Analytics for Firebase) and **crash reports** (Firebase Crashlytics). They help us see which features are used and where people get stuck — nothing more.

**Never sent:** your URLs, headers, tokens, request bodies, responses, metric titles or values. No accounts, no email, no advertising identifier (IDFA) — the app uses `FirebaseAnalyticsCore` without ad support. Widgets send no analytics.

## What is sent

Event names with short technical parameters:

| Event | When | Parameters |
|---|---|---|
| `onboarding_shown` | Onboarding opened | — |
| `onboarding_skipped` | Onboarding closed without adding a metric | — |
| `gallery_opened` | Gallery opened | `entry`: `main` / `onboarding` |
| `metric_added` | A new metric is added | `source`: `gallery` / `custom` / `import` / `onboarding`, `type`, `result_kind`; for gallery items also `gallery_id`, `gallery_group` |
| `metric_form_started`, `metric_form_step`, `metric_form_saved`, `metric_form_abandoned` | Creating a custom metric | `step`: `request` / `value` / `display` |
| `metric_request_tested` | Test request in the form | `success`, `error_kind`: `network` / `http` / `parse` / `unknown` |
| `metric_refreshed`, `library_refreshed` | Metrics refreshed | `success`, `error_kind`, `library_size`, `failed_count` |
| `metric_edited`, `metric_deleted` | Metric edited or removed | `type`, `result_kind`, `is_starter` |
| `metric_shared`, `metric_share_cancelled`, `app_link_copied` | Sharing | `include_request`, `includes_file`, `activity` (share target, e.g. Messages) |
| `widget_guide_shown`, `widget_guide_dismissed` | Widget guide | `dont_show_again` |
| `review_shown`, `review_later`, `review_completed`, `review_declined` | Rating prompt | `trigger`, `library_size`, `source` |

User properties: number of metrics, number of custom metrics, whether onboarding is done.
Firebase also adds its standard data: app version, iOS version, device model, approximate country, and automatic events like `first_open` and `session_start`.

The full list lives in one file — [`AnalyticsEvents.swift`](AnyMetrics/Utils/AnalyticsEvents.swift). Debug builds send nothing. Event data is deleted after 14 months.

Details: [Privacy Policy](privacy_policy.md).
