# Live deployment preflight

Checked the app-configured MyClubs project (`bfntlbisipxgzxdmwxkz`) on 2026-09-12. These were pre-deployment checks; the authorized deployment and verification are recorded below.

- All 16 required tables, referenced columns/types, RLS flags and necessary authenticated read privileges are present. Profiles use column-level SELECT privileges rather than unrestricted table SELECT; every projected profile column is allowed.
- The existing actor-checked private blocking helper exists and authenticated callers can use it.
- All eight new function names and both new index names are unused on the live database. No existing API will be replaced by this migration.
- Existing feed and conversation-summary v2 functions are present. The migration does not alter them, existing tables/columns, policies, storage, authentication settings, or application records.
- Live migration history differs from the repository's historical filenames. A normal repository-wide push refuses to proceed. Do not repair/replay that history as part of this performance deployment.
- Downloaded live migration history into an isolated temporary deployment directory and added only the tested performance file. Its dry run succeeds and includes exactly `20260911154857_app_performance_pages_v1.sql`, with no seeds or role changes (`--skip-vault`). No history repair is required.
- Deployment file matches the tested repository file byte-for-byte: SHA256 `6dc2c783639cf985504e0756bde756cc597b52553ef4c98aef2df00f6c9f4af0`.

The database changes are backward-compatible by inspection: the released app continues to use its existing endpoints. Index creation can briefly delay writes; the indexed live relations are currently small (approximately 80 KB events and 112 KB profiles including their existing indexes). This is a compatibility preflight, not a guarantee of zero deployment risk or an end-to-end test of the App Store binary.

Temporary prepared directory: `/tmp/clubup-performance-deploy`. Recheck the live history and file hash immediately before deployment. After deployment, verify the new functions/grants and the unchanged existing API definitions. Physical-device and full-suite validation limits remain in README.md.

## Deployment completed

Deployed the single checked performance migration to MyClubs after the user's authorization. No seeds, custom roles, vault changes, or historical migrations were applied. The migration is recorded and both new indexes are ready and valid.

Post-deployment fingerprints match the pre-deployment fingerprints for **all existing public/private function definitions and grants, application/auth/storage relation and column permissions, RLS policies, and triggers**. All eight new functions are invoker-security functions available to authenticated callers and unavailable to anonymous callers.

Read-only authenticated smoke checks passed for the old feed and conversation-summary APIs, new student/club directories, event/post pages, categories, member pages, club totals, and the administrator overview. Only response types were returned; no user content was recorded. No App Store binary or application records were changed.

Machine-readable evidence: [deployment-verification.json](deployment-verification.json). Device validation limits remain unchanged; these checks are not an end-to-end run of the App Store binary.
