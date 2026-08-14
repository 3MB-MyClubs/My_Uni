# Startup resilience

`runApp()` is invoked immediately after Flutter binding and release-safe error
handlers are installed. No filesystem, plugin, Firebase, Supabase, session, or
Data API future is awaited before the first Flutter frame.

## Post-frame startup audit

| Operation | Can throw | External wait | Bound/fallback |
| --- | --- | --- | --- |
| Firebase initialization | Yes | Native plugin | 5 seconds; push setup is skipped |
| Supabase initialization/session storage | Yes | Plugin/network/local storage | 5 seconds; app continues signed out for this launch |
| `path_provider` + Hive initialization | Yes | Plugin/filesystem | 5 seconds; in-memory defaults remain usable |
| Theme, locale, Terms, intro boxes/preferences | Yes | Hive/SharedPreferences | 3 seconds each; neutral local defaults remain usable |
| Deferred Hive boxes | Yes | Filesystem | 5 seconds each; hydration is skipped unless all required boxes opened |
| Persisted-session restoration | Yes | SharedPreferences/auth/Data API | One 8-second deadline over refresh and all classification/profile/Terms work |
| Invalid-session cleanup | Yes | SharedPreferences/auth plugin/network | 2 seconds; in-memory auth remains closed even if cleanup stalls |
| `user_preferences` read/write | Yes | Data API | 3 seconds; same-account cache or neutral values are returned for a read timeout |
| Mandatory update check | Yes | Data API/package-info plugin | Existing 5-second deadline; app continues when unavailable |

## Authentication outcomes

- A timeout or general network failure does not clear Supabase's persisted
  token pair or the device session timestamp. The app presents signed-out UI
  for this launch and can retry on a later launch/login.
- An expired access token is refreshed inside the restoration deadline. A
  successful refresh continues normal role/profile classification.
- A confirmed invalid/revoked refresh credential, a mismatched platform-admin
  assignment, a broken club-account link, or a banned account clears local
  authentication and remains signed out.
- With no saved session, restoration performs no role/profile network reads and
  continues to logged-out UI.

Terms acceptance remains fail-closed: a missing, failed, or timed-out Terms read
never grants authenticated application access. Account-preference failure does
not grant a role or bypass Terms; it only suppresses first-time preference
prompts until a successful retry establishes authoritative state.
