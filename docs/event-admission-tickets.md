# Free event admission tickets

Create/edit event has a **Ticketed event / Biletli etkinlik** toggle, off by default. The description explains that organizers issue free tickets manually after RSVP. Ordinary events do not display ticket cards or scanner/issuance controls.

For ticketed events, the event management page has **Scan tickets** above its attendee list and a ticket icon beside each attendee. Staff can issue, revoke, or reissue a ticket there. Attendees see a **See your ticket** button on the event page; the admission QR and a six-character ticket code appear on the separate ticket page. Organizers see the same code in the attendee list. If the camera cannot scan, staff can type that code in the scanner screen to check in the attendee. Existing manual check-in stays available. English and Turkish copy is included.

## Rules and authorization

- Ticketing must be enabled and an RSVP is required to issue a ticket. Issuance is idempotent: repeating it returns the current ticket. There is one non-revoked ticket per event/attendee, enforced by a partial unique index.
- Reissue replaces an active, revoked, or used credential and permanently revokes its predecessor. A new ticket starts another admission cycle by clearing the current check-in; the old ticket retains its usage record and cannot admit again.
- Cancelling an RSVP revokes its ticket. RSVPing again does not reactivate that credential; staff must issue a replacement. A previous ticket admission does not prevent a new staff-issued ticket.
- Club authentication accounts, linked board members in the club account context, and platform admins use the existing `private.can_manage_event` permission model. Removing a board role immediately removes ticket permissions. Ticket holder identity and acting staff identity are different: the server derives the latter from `auth.uid()`.
- No payment, purchase flow, offline admission, or admission from event-sharing QR codes is included. Manual check-in remains the staff override for walk-ins and attendance corrections.
- Manual ticket-code entry is event-scoped and requires organizer authorization. It uses the same ticket consumption checks as QR scanning, so revoked and used codes cannot admit again. A successful code entry is recorded as a manual check-in.

- Disabling ticketing revokes all current tickets. Reenabling does not restore them. The server serializes toggle changes against issuance and scans with an event row lock. Events with tickets already manually issued before this migration retain ticketing; other existing events default off.
- Creating a ticketed event, enabling its toggle, and RSVPing **never issue tickets automatically**. Issuance is always a separate authorized staff action.

## Credential and transaction design

The QR payload is `clubup-ticket:v1:<64 lowercase hex characters>`. Supabase generates 32 cryptographically random bytes with `pgcrypto`, independent of the profile ID, event ID, and ticket row ID. Sharing URLs are not ticket credentials.

Each ticket also has a unique six-character code containing letters and numbers. That code is shown to the attendee and organizer. It is a manual entry fallback; the QR retains its longer credential. Reissuing a ticket changes both values.

`event_tickets` has RLS and authenticated SELECT only. The holder and authorized event staff can read credentials; other users and anonymous clients cannot. Credentials remain in widget memory and are not written to Hive, logs, analytics, URLs, or shared event messages. The database stores the credential so the holder can redisplay their ticket; backups and administrative database access must be treated as sensitive.

Authenticated public RPC wrappers invoke permission-checked routines in the unexposed `private` schema, with an empty search path and explicit EXECUTE grants. Clients cannot directly insert, mutate, delete, or choose a ticket token.

Issuance first locks the enabled event row, then locks the RSVP row before locking/replacing a current ticket. When it creates a new ticket, it clears the current check-in in the same transaction. Scanning locks the RSVP (key share), then the ticket (`FOR UPDATE`), and checks revocation/consumption again under the lock. It inserts the canonical `event_checkins` row and marks the ticket consumed in that same transaction. The existing `(event_id, profile_id)` uniqueness constraint resolves conflicts with manual admissions too. RSVP cancellation and reissue use a compatible lock order. Old revoked rows remain available to distinguish revoked credentials from unknown ones.

Scan results are `checked_in`, `already_used`, `revoked`, `wrong_event`, and `invalid`. Wrong-event responses contain no holder/event details. Permission failures raise `42501` before credential lookup. Network failure never displays admission success: a response can be lost after commit, so the staff member must deliberately rescan; that returns `already_used` if the first scan committed. Repeated camera callbacks are suppressed until the staff member chooses **Scan next ticket**.

## Deployment

1. Apply the event-ticket migrations in order through the normal Supabase migration deployment **before** shipping the Flutter update, including `20260927072904_event_ticket_display_codes.sql` and `20260927073909_manual_ticket_code_checkin.sql`. All earlier migrations must already be applied.
2. Run `flutter pub get` and rebuild native apps. `mobile_scanner` is pinned to 7.4.2; camera purpose text and macOS camera entitlements are included. iOS/Android builds integrate their native plugin dependencies; web camera access requires a secure origin.
3. Smoke-test on real iOS and Android devices: permission denied/allowed, background/resume, valid QR, second scan, wrong event, revoke/reissue, manual check-in, and network loss. Camera hardware recognition cannot be proved by widget tests or simulator compilation.
4. No tickets are backfilled or automatically issued for existing RSVPs. Organizers enable ticketing and then issue tickets from the attendee list.

## Automated verification

```sh
flutter test test/event_ticket_service_test.dart test/event_ticket_ui_test.dart test/event_edit_authorization_test.dart
flutter analyze --no-fatal-infos lib test
supabase test db supabase/tests/*.test.sql --local
python3 scripts/test-ticket-concurrency.py
bash scripts/check-database-lint.sh
bash scripts/check-migration-versions.sh
```

The concurrency script uses only the local `supabase_db_My_Uni` Docker container, creates temporary UUID fixtures, runs 12 overlapping transactions, asserts one admission, and removes its fixtures. It needs no production credentials. These ticket suites are included in the release gate. Database types are regenerated from the complete local migration history (including previously missing audience/v3 RPC definitions).

## Verification on 2026-09-25

- All **463 pgTAP assertions across 20 suites** passed after the opt-in migration, including 61 ticket/opt-in assertions.
- All **83 Flutter release-gate and ticket/event-authorization tests** passed (19 in the targeted ticket/event set).
- Concurrent issuance returned one credential to all 12 callers; concurrent scanning admitted exactly one of 12 callers; all scans after revocation were rejected.
- A temporary local PostgREST instance verified the real HTTP contract: single-row issuance, idempotent issuance, holder/stranger RLS, unauthorized issuance, permission lookup, revocation, reissue, and first/duplicate scan.
- `flutter analyze --no-fatal-infos lib test`, migration version checks, repository database lint, iOS simulator compilation, and web release compilation passed. Private ticket routines were included in database lint.
- Advisors reported only the two existing multiple-permissive-delete-policy performance warnings for `events` and `club_posts`; no ticket findings. The repository lint script permits its existing notification temporary-table false positive.
- Four older tests fail identically on clean `HEAD`: the creator-access case in `event_attendance_privacy_test.dart`, the signup/RSVP case in `rsvp_button_test.dart`, and both `event_share_visual_qa_test.dart` goldens. Ticket changes do not alter those tests or golden images.
- At the time of this verification, production migration deployment, Android compilation, and physical-device camera smoke tests had not been performed. No production data was changed during these checks.

### Opt-in follow-up verification

The optional-ticketing update passed 39 Flutter tests for the toggle, model persistence, event editing, ticket service/UI, audience settings, feed controller, and transactional contracts. Full Flutter analysis and database lint passed. Twelve simultaneous scans still admit exactly one attendee. Two additional legacy `feed_event_edit_refresh_test.dart` cases fail on both the updated tree and clean `HEAD` because their expected mock club-admin fixture is absent. The optional-ticketing migration was replayed successfully from a clean local database.

### Live reissue update

On 2026-09-25, the three ticket migrations were recorded on the connected Supabase project. The reissue migration was applied as remote migration `20260925112722` and verified against the live function definition: the old checked-in rejection is absent, the current check-in is cleared when a new ticket is issued, and authenticated clients retain permission to call the issuance RPC. The migration did not issue tickets or alter existing ticket rows; staff must explicitly reissue a ticket.
