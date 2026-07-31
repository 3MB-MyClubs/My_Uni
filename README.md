# ClubUp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Live device preview

Run the app in a desktop browser with an interactive phone/tablet frame:

```sh
flutter run -d chrome --dart-define=CLUBUP_DEVICE_PREVIEW=true
```

Use the toolbar to switch between iPhone, Pixel, and iPad sizes or rotate the
device. Press `r` in the Flutter terminal after saving code to hot reload the
preview live. The preview is debug-only and is disabled in normal and release
runs.

## Mock club admin

For local development, start the app with mock authentication enabled:

```sh
flutter run --dart-define=ALLOW_MOCK_AUTH=true
```

Then choose **Club admin sign in** and enter:

- Club name: `ClubUp`
- Passcode: `11111111`

This creates a local ClubUp club-admin profile only for that development
session. Mock authentication is disabled in release builds.

Only this ClubUp profile sees the **Settings → ClubUp moderation center**
entry. Reports and bans in the mock center are stored on the current device;
production, cross-device moderation requires an authenticated server-side
moderator role and must not expose a Supabase service-role key in the app.

## Production app admin

The production app-wide moderator is stored in the singleton Supabase
`app_admins` table. From the main login screen, tap **Club admin sign in** five
times within the gesture window to open its separate login UI. Enter
`dev3mb@gmail.com` and the account's 8-digit passcode. Authorization
still comes from the authenticated user's RLS-protected `app_admins` row; the
hidden gesture is only a navigation affordance. The normal club-admin login
rejects the platform-admin identity, and ordinary club-owner accounts remain
club-scoped.

## Android release signing

Google Play requires release APKs and app bundles to be signed with an upload
key. If this app has already been registered in Play Console, use its existing
upload key; creating a different key will require an upload-key reset.

1. Create an upload keystore if you don't already have one:

   ```sh
   keytool -genkey -v -keystore ~/upload-keystore.jks -storetype JKS \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Copy `android/key.properties.example` to `android/key.properties`, then set
   the keystore path, alias, and passwords. Both the properties file and
   keystore are ignored by Git and must remain private.

3. Build the release app bundle:

   ```sh
   flutter clean
   flutter build appbundle --release
   ```

The signed bundle is written to
`build/app/outputs/bundle/release/app-release.aab`.

## ClubUp support website

The localized static website in `docs/` contains the public ClubUp support,
privacy, and account-deletion pages in English and Turkish. English pages use
the root URLs and Turkish pages use the `/tr/` path. The GitHub Actions workflow in
`.github/workflows/deploy-pages.yml` validates and deploys it to GitHub Pages
whenever related files change on `main`.

The public support, privacy, and account-deletion contact is
`dev3mb@gmail.com`. The validator blocks publication if a contact placeholder
is introduced in the site.

Expected public URLs:

- `https://3mb-myclubs.github.io/My_Uni/`
- `https://3mb-myclubs.github.io/My_Uni/support/`
- `https://3mb-myclubs.github.io/My_Uni/privacy/`
- `https://3mb-myclubs.github.io/My_Uni/delete-account/`
- `https://3mb-myclubs.github.io/My_Uni/tr/`
- `https://3mb-myclubs.github.io/My_Uni/tr/support/`
- `https://3mb-myclubs.github.io/My_Uni/tr/privacy/`
- `https://3mb-myclubs.github.io/My_Uni/tr/delete-account/`
