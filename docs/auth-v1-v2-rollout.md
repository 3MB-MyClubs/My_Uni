# Authentication v1/v2 rollout

This rollout intentionally maintains two independent verification protocols.
Normal password sign-in continues to use Supabase Auth directly and is not
versioned.

## Endpoint and state ownership

| Operation | Legacy released app | New app |
| --- | --- | --- |
| Signup request | `send-signup-code` | `send-signup-code-v2` |
| Signup verify | `verify-signup-code` | `verify-signup-code-v2` |
| Signup complete | `complete-signup` | `complete-signup-v2` |
| Reset request | `send-password-reset-code` | `send-password-reset-code-v2` |
| Reset verify | `verify-password-reset-code` | `verify-password-reset-code-v2` |
| Reset complete | `complete-password-reset` | `complete-password-reset-v2` |
| Mutable state | `public.pending_signups`, `public.pending_password_resets` | `private.signup_challenges_v2`, `private.password_reset_challenges_v2` |

The v1 endpoints preserve the released JSON request/response contract. They
use the historical `verified` flag only in the legacy tables, with five
attempts, a 60-second resend cooldown, expiry, row locks, and atomic one-time
consumption added without requiring new client fields. V1 also retains the
released `${email}:${code}:${pepper}` hash domain so an in-flight code remains
valid while the six legacy functions are updated during a rolling deployment.

The v2 verification endpoints return a random capability. Only its
operation/email-bound hash is stored, and the v2 completion endpoints require
and atomically consume that capability. A v1 verification cannot mint a v2
capability, and neither protocol reads or deletes the other's rows.

All twelve verification endpoints are pre-authentication endpoints and must be
deployed with JWT gateway verification disabled. They still require the
project API key supplied by the Supabase client and enforce their controls in
the function/database implementation.

## Safe deployment order

Do not use an indiscriminate migration push until production migration-history
drift has been reconciled. Apply and record these files in this exact order:

1. Apply `20260812114050_restore_legacy_auth_compatibility.sql`. This drops
   only the two F1 constraints that currently prevent the deployed legacy
   verify functions from setting `verified=true`; the existing released app
   starts working again immediately.
2. Apply `20260812114051_restore_authenticated_profile_email_visibility.sql`.
   Confirm authenticated peer email access and anonymous denial.
3. Smoke-test all six currently deployed v1 endpoints using the released app
   request bodies, followed by normal `signInWithPassword`.
4. Apply `20260812114104_create_v2_auth_challenges.sql`.
5. Confirm `20260812105930_application_rate_limits.sql` has been applied. Both
   updated v1 and v2 functions fail closed if their rate-limit RPC is missing.
6. Deploy the six updated unversioned v1 functions with JWT verification
   disabled. They keep the same HTTP contracts and released hash domain but
   switch state transitions to the locking legacy RPCs from step 1. Repeat the
   v1 smoke test.
7. Deploy all six `*-v2` functions with JWT verification disabled.
8. Smoke-test signup and reset through v2, including capability replay and
   password-reset session revocation. Re-run the protocol-isolation tests.
9. Release the Flutter version that calls only the six v2 endpoints.
10. Keep v1 active until App Store adoption and backend invocation telemetry
   show that the minimum supported version no longer uses it.
11. Remove v1 in a separate backend release. Do not combine removal with the
    Flutter rollout.

Database migrations and Edge Function deployments are not atomic. Never
deploy v2 functions before the v2 schema, and never deploy the updated v1
functions before the legacy repair migration.

## Legacy removal gate

Legacy support is safe to remove only when all of the following are true:

- the minimum supported iOS version contains the v2 endpoint names;
- App Store adoption has exceeded the product-approved threshold for the full
  observation window;
- Edge Function invocation telemetry shows negligible or zero v1 traffic;
- support has confirmed no active rollout/review cohort still needs v1;
- a rollback build that uses v2 remains available.

The later removal migration should drop the six `*_legacy` RPCs, the original
unused F1 RPCs that still reference `public.pending_*`, and the two legacy
pending tables. The same release should delete or seal the six unversioned
Edge Functions. Keep the private email RPCs until their callers have been
separately migrated; they are unrelated to auth protocol removal.

## Security boundary

V1 remains a temporary compatibility protocol and retains its historical
email-level verification window and account-existence responses by explicit
product decision. V2 does not inherit that behavior: it has independent
private rows, generic account-existence responses, hashed capabilities, short
expiry, locking, one-time consumption, replay rejection, and reset session
revocation. No v1 field or row can authorize a v2 completion.
