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
