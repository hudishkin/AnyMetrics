# AnyMetrics Privacy Policy

**Effective date:** November 22, 2026

AnyMetrics is a free, open-source iOS app by Semen Khudyshkin. This policy explains what data the app handles and where it goes. The source code is public, so every statement here can be checked.

## Short version

- Your metrics — URLs, headers, API keys, request bodies, responses and values — stay on your device.
- An account is needed only for AI generation. If you use it, the AnyMetrics server receives your sign-in details, what you type into the generator, and your credit purchases. You can delete the account in the app.
- With Sign in with Google, AnyMetrics receives only your Google account ID, email and name. It does not access any other Google data and never sells or shares it.
- The app sends anonymous usage events and crash reports to Google Firebase so I can improve it.
- No ads, no advertising identifier (IDFA), no selling or sharing of data for marketing.

## Data stored on your device

Metrics you create or import are stored locally in the app's private storage, which is shared only with the AnyMetrics widget so it can show your data. This includes request URLs, methods, headers, bodies, parsing rules, widget styles, background images and the latest values.

This data is not synced to iCloud and is never sent to me. Deleting the app deletes it.

## Requests to your endpoints

The app and its widget send HTTP requests directly from your device to the URLs you configure — nowhere else. These requests contain whatever URL, headers and body you set up. The services you call are governed by their own privacy policies.

## Account and AI generation

Everything except AI generation works without an account.

**Sign-in.** To generate metrics you sign in with Apple, Google or GitHub. The provider gives the AnyMetrics server a sign-in token, from which the server learns your account ID and, if the provider shares them, your name and email. With Sign in with Apple you can hide your email. The app keeps a session token in the iOS Keychain.

**Generation.** The server receives the description you type, your device language, and your answers to follow-up questions. It uses them to find a public data source and build a metric, which comes back to the app. Your saved metrics, their URLs, headers and API keys are never sent.

**Credits.** Purchases go through the App Store; the app never sees your payment details. After a purchase the app sends Apple's signed transaction to the server so it can add credits to your account. The server keeps your credit balance.

**Deleting your account.** Profile → ⋯ → Delete account closes the account on the server and signs it out on every device. It cannot be signed into again. The account record, balance, purchases and generation history are kept on the server until they are removed later. Metrics on your device are not affected.

The full list of server calls and their contents is in [docs/builder-api.md](docs/builder-api.md).

## Google user data

AnyMetrics uses Google Sign-In only to authenticate you. We access your name and email address and use them solely to create and identify your account. We do not use Google user data to train AI models and do not use Google APIs to generate images, including non-consensual intimate imagery. AnyMetrics' use of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

This section describes what AnyMetrics receives when you choose **Sign in with Google**. Google sign-in is optional. It is used only to create and sign in to your AnyMetrics account, which you need for AI generation.

**Data accessed.** The app requests only the `openid`, `email` and `profile` scopes. From the ID token that Google returns, the AnyMetrics server reads your Google account ID, your email address and your name. AnyMetrics does not request access to Gmail, Google Drive, Contacts, Calendar or any other Google service, and does not use your profile photo.

**How it is used.** Your Google account ID, email and name are used only to create and identify your AnyMetrics account, to show your name and email on the Profile screen, to link credit purchases to your account, and to stop a deleted account from being signed into again. They are not used for advertising, analytics or profiling, are not included in AI generation requests, and are not used to train AI or machine-learning models.

**AI and image generation.** AI generation in AnyMetrics builds metric definitions from the text you type; it does not create images. AnyMetrics does not use Google APIs or Google user data to generate images, and does not generate or allow non-consensual intimate imagery.

**Storage and protection.** The sign-in runs in a secure system browser window with PKCE. On your device the app exchanges Google's one-time code for an ID token and sends only that ID token to the AnyMetrics server over HTTPS. The app does not keep Google access or refresh tokens and makes no other calls to Google APIs on your behalf. The server stores your Google account ID, email and name with your account record. The app keeps its own AnyMetrics session token in the iOS Keychain.

**Sharing.** Google user data is not sold, rented or shared with third parties, and is not sent to Firebase. It is disclosed only if required by law.

**Retention and deletion.** The data is kept while your account exists. Profile → ⋯ → Delete account closes the account and signs it out on every device. To have your Google account ID, email and name erased from the server, email [anymetrics.app@gmail.com](mailto:anymetrics.app@gmail.com) and I will delete them and confirm by email. You can also remove AnyMetrics' access at any time in your [Google Account settings](https://myaccount.google.com/connections).

**Limited Use.** AnyMetrics' use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## Usage analytics

The app uses **Google Analytics for Firebase** (without the advertising module) to understand which features are used and where people get stuck. It sends:

- **Events** about app usage, such as "onboarding shown", "metric added", "metric form abandoned at step X", "refresh failed: network error", "review prompt shown".
- **Short technical parameters** for those events: metric type, where a metric came from (gallery, custom, import), success/failure, error category, number of metrics.
- **Standard Firebase data:** an app-instance identifier generated by Firebase, app version, iOS version, device model, language, and approximate location (country/city) derived from the IP address. Google Analytics does not store IP addresses.

Analytics **never** include your URLs, headers, API keys, request bodies, responses, metric titles or values.

The complete list of events and parameters is in [`AnalyticsEvents.swift`](AnyMetrics/Utils/AnalyticsEvents.swift) and in [ANALYTICS.md](ANALYTICS.md). Event data is kept for 14 months, then deleted automatically.

## Crash reports

The app uses **Firebase Crashlytics**. When the app crashes, it sends a crash report: stack trace, device model, iOS version, app version, free memory and disk space, and a Crashlytics installation identifier. Crash reports do not include your metrics. Google keeps them for 90 days.

## Gallery

When you open the Gallery, the app downloads the list of ready-made metrics from GitHub ([hudishkin/AnyMetricsGallery](https://github.com/hudishkin/AnyMetricsGallery)). As with any download, GitHub sees your IP address. See [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Sharing and export

When you share or export a metric, the app creates an image and/or a JSON file and hands it to the iOS share sheet. You decide where it goes. If you choose to include the request, the file may contain headers or API keys — the app shows a warning before sharing.

## Third-party services

- [Google Firebase privacy and security](https://firebase.google.com/support/privacy)
- [Google Privacy Policy](https://policies.google.com/privacy)

## Your choices

- Deleting the app removes all locally stored data and resets the Firebase identifiers on your device.
- Deleting your account in the app closes it on the server and signs out every device. To have its data erased right away, contact me at the address below.
- To request deletion of analytics data associated with your device, contact me at the address below.

## Children

AnyMetrics is not directed at children under 13 and does not knowingly collect personal information from them.

## Changes

If this policy changes, the updated version will be published here with a new effective date. The full history of changes is available in the repository.

## Contact

Questions or requests: [anymetrics.app@gmail.com](mailto:anymetrics.app@gmail.com)
