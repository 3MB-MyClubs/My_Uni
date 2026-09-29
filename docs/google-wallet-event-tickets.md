# Google Wallet event tickets

The ticket number and text next to the barcode show the same six-character code visible to the attendee and organizer in the app. The QR retains its separate admission credential.

On Android, active attendee tickets show **Add to Google Wallet** when the Google Wallet save API is available. The app requests a signed event ticket JWT from the `google-wallet-ticket` Edge Function and passes it to Google's native save sheet. The ticket QR uses the same `clubup-ticket:v1:<token>` credential as the in-app QR; `scan_event_ticket` remains the admission authority.

## Setup

1. Create a Google Wallet issuer account and event-ticket class in the Google Pay & Wallet console. While the account is in demo mode, add Android test accounts there. Production distribution requires Google publishing access.
2. Enable the Google Wallet API in a Google Cloud project. Create a dedicated service account and grant its email **Developer** access under the Wallet console's **Users** section. Create a JSON key for the service account and keep it outside the repository.
3. Set these Supabase Edge Function secrets: `GOOGLE_WALLET_ISSUER_ID` (the numeric Wallet issuer ID), `GOOGLE_WALLET_SERVICE_ACCOUNT_EMAIL` (JSON `client_email`), and `GOOGLE_WALLET_PRIVATE_KEY` (JSON `private_key`, without JSON quotes). The private key may contain literal `\\n` escapes or real line breaks. Never put the JSON key or private key in Git, app assets, Dart code, or screenshots.
4. Deploy `google-wallet-ticket` with JWT verification enabled. The function uses the caller's Auth token and RLS plus an explicit ticket-holder predicate. It has no service-role access.

The function creates one Wallet class per event and one object per ticket when the user saves it. Class IDs are generated from event UUIDs; the demo class created manually in the console is only for issuer onboarding. The pass is signed on the server and transferred to Android's `savePassesJwt` API without creating a browser URL containing its QR token.

## Verify

On a physical Android device with an authorized demo test account, sign in as an active ticket holder and tap **Add to Google Wallet**. Check that Google's sheet shows the event, attendee, and QR. Save it and scan its QR with the existing event scanner. Revoke or reissue the ticket and scan the old Wallet pass again; the server must reject it. A reissued ticket gets a new object ID and QR.

Existing passes are not pushed updates when a ticket is revoked, used, or reissued. The QR may remain visible in Wallet, but the scanner rejects it after those state changes. Google Wallet object updates would require a separate integration.
