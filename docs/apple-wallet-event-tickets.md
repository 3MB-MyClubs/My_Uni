# Apple Wallet event tickets

The attendee ticket card shows **Add to Apple Wallet** on iOS when Wallet can add passes. The app requests a fresh, signed `.pkpass` from `apple-wallet-ticket`, then opens Apple's add sheet. The server checks the signed-in user owns an active ticket before it generates the pass. The six-character ticket code appears as a pass field and barcode text. The Wallet QR contains the same `clubup-ticket:v1:<token>` credential as the in-app QR; `scan_event_ticket` remains the admission authority. The organizer sees the same code in the attendee list and ticket management sheet. A reissued ticket gets a new code.

## Certificate setup

The Apple Pass Type ID is `pass.com.3mb.clupup.events` and the team ID is `BPNS3G27Y8`. Generate its Pass Type ID certificate in Apple Developer and export the certificate **with its private key** from Keychain Access as a password protected `.p12` outside this repository.

Run the local converter, passing the location of that `.p12`:

```sh
python3 scripts/prepare_apple_wallet_secrets.py /absolute/path/to/ClupUp-Wallet-Pass.p12
```

It prompts for the export password and creates a mode-600 secrets file in the system temporary directory. It does not print the key. Upload the file to the connected Supabase project with the CLI (`supabase secrets set --env-file <generated-path>`) or enter its four values in **Edge Functions → Secrets**. Delete the temporary file after upload. Do not put the `.p12`, its password, or generated secrets file in this repository or the mobile app. The public Apple WWDR G4 intermediate is bundled with the function from [Apple PKI](https://www.apple.com/certificateauthority/).

Deploy `apple-wallet-ticket` with JWT verification enabled. The Supabase Auth token is sent by `supabase.functions.invoke`; the function also checks the user ID against the ticket holder. It has no service-role access.

On 2026-09-25, version 1 was deployed to the MyClubs production project with JWT verification enabled. The four signing secrets were saved in Edge Function Secrets. An unauthenticated request returned HTTP 401. A physical iPhone test with an issued ticket is still required to confirm Apple's add sheet and admission scan end to end.

## Acceptance check

On a physical iPhone signed in as a ticket holder, open an active ticket and tap **Add to Apple Wallet**. Apple's add sheet should show the event name, attendee, venue, and QR. Add it, then scan its QR with the existing event scanner. Revoke or reissue that ticket and scan the old Wallet pass again; it must be rejected by the server. A reissued ticket has a new serial number and must be added as a new pass.

Existing passes are not pushed updates when a ticket is revoked, used, or reissued. The QR remains visible in Wallet, but the server rejects it after those state changes. Apple Wallet push updates would require a separate pass update web service.
