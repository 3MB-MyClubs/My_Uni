# Production migration reconciliation audit

Project: `bfntlbisipxgzxdmwxkz`  
Audit date: 2026-08-13  
Mode: read-only production metadata and schema inspection

## Safety statement

No migration, history repair, schema/data mutation, function deployment, Cron/Vault change, or storage mutation was performed. Production access was limited to project metadata, migration-history reads, generated types, and PostgreSQL catalog/schema queries.

## Executive conclusion

- Local migrations: **74**.
- Production migration-history rows: **51**.
- Version matches: **19**.
- Local-only versions: **55**.
- Remote-only versions: **32**.
- All 32 remote-only rows have authoritative SQL in `supabase_migrations.schema_migrations.statements`; none of their production version numbers exists in Git history.
- All 32 can be associated with local or archived SQL by effect. Most are timestamp-renamed equivalents, but two have source drift and several local changes are present in production without a history row.
- Production is not at the repository's reproducible final schema. The v2 rate-limit, auth-v2, F2/F3-v2, Feed-v2, Chat-v2, Notification-v2, transactional/storage-v2, media-v2, and reproducibility-repair sequence is absent.
- Four older local-only entries remain unsafe to reconcile automatically: `001`, `006`, `010`, and `20260803120000`.
- No verified production restore checkpoint exists: WAL-G is enabled, PITR is disabled, and the backup list is empty.

Therefore, this audit supplies a safe plan but does **not** establish that production mutations are safe to resume.

## Comparison method and fingerprints

Each local SQL file was summarized by statements that create or alter tables/columns, constraints, functions, policies, triggers, indexes, grants, publications, and storage configuration. The fingerprint is SHA-256 over SQL after removing comments, collapsing whitespace, and lowercasing. Prefixes below are sufficient identifiers for this repository snapshot; the full digest should be regenerated before any future reconciliation session.

Production comparison used actual catalogs, not version names alone: columns/defaults/nullability, constraints, indexes, function signatures/definitions, triggers, RLS policies, grants, storage metadata/policies, and `supabase_realtime` publication membership.

## Local migration inventory

Legend: `T` tables, `C` columns/constraints, `F` functions, `P` policies, `Tr` triggers, `I` indexes, `G` grants/revokes, `S` storage/publication. “Matched” means the same version exists remotely; it is not a content-hash claim.

| Version / filename | FP | Major normalized effect | History |
|---|---:|---|---|
| `00000000000000_core_schema_bootstrap.sql` | `be3253de9edd` | T/C: fresh-install core public/private schema; F/P/Tr/I/G/S: canonical functions, RLS, triggers, indexes, grants, buckets/publications | Local-only |
| `001_post_comments.sql` | `68c6194ab731` | T `post_comments`; C comment/thread fields and FKs; P comment CRUD; I post/profile; G API roles | Local-only |
| `002_event_checkins.sql` | `bbc358203e6a` | T `event_checkins`; C event/profile uniqueness; F check-in helpers; P/Tr/I/G | Local-only |
| `003_polls_announcements.sql` | `bf60ab7907ac` | T `polls`,`poll_options`,`poll_votes`; C `club_posts.is_announcement`; F/P/Tr/I/G | Local-only |
| `004_direct_messages.sql` | `f9f34790b2dc` | T direct-message threads/messages/members; F/P/Tr/I/G/S Realtime | Local-only |
| `005_legacy_features.sql` | `4da1400f270d` | C DM delivery status; T moderation reports/user blocks; F/P/Tr/I/G | Local-only |
| `006_legacy_features.sql` | `9651e08dbd3e` | T club blocks; F/P app presence; S `club_followers` replica identity/publication | Local-only |
| `007_legacy_features.sql` | `b3683043c9ad` | T group chats/messages/members; test-club visibility; F/P/Tr/I/G/S | Local-only |
| `008_legacy_features.sql` | `fcd21ac1a648` | C group photo and profile test flag protection; storage policies; P/G | Local-only |
| `009_group_member_order.sql` | `db9f27e0b18e` | C group-member ordering; F/Tr/I | Local-only |
| `010_legacy_features.sql` | `ced3a3a3ca0e` | T group message receipts; C academic-year reference changes; P/Tr/I/G/S | Local-only |
| `011_security_performance_hardening.sql` | `b0774faa0d12` | F security hardening; P RLS corrections; I performance indexes; G/revokes | Local-only |
| `012_finalize_rls_hardening.sql` | `93fe5149876d` | P final RLS cleanup; F search-path/security fixes; I/G | Local-only |
| `013_make_event_images_public.sql` | `58c619d987b6` | S make `event-images` public | Local-only |
| `014_terms_acceptances.sql` | `76c7f03f7bee` | T terms acceptances; F accept/current terms; P/I/G | Local-only |
| `20260730110505_add_push_devices.sql` | `9e0705025d2a` | T push devices; F/P/Tr/I/G | Local-only |
| `20260730112513_add_notification_delivery_pipeline.sql` | `ac2b2d35172e` | T notification delivery jobs; F enqueue/dispatch; Tr notification enqueue; P/I/G | Local-only |
| `20260730113012_harden_notification_inbox.sql` | `6d7fbda1308d` | P notification inbox isolation; F/G hardening | Local-only |
| `20260730113110_harden_chat_policies.sql` | `b71e9718023f` | P chat membership/read/write hardening; F/G | Local-only |
| `20260730121836_improve_notification_copy.sql` | `0608109ef496` | F/Tr notification copy generation | Local-only |
| `20260730122711_localize_push_notifications.sql` | `8a19d87ab45a` | F localized push payload/copy | Local-only |
| `20260730205550_add_e2ee_messaging.sql` | `39b3412096cd` | T/C/F/P/Tr/I/G E2EE messaging | Matched |
| `20260730205724_enable_chat_data_api_access.sql` | `2bb23ca6eb63` | G Data API schema/table/function access | Matched |
| `20260730210639_recover_orphaned_e2ee_threads.sql` | `1efb3b8bf403` | F/C repair orphaned E2EE thread state | Matched |
| `20260730212707_realtime_e2ee_key_delivery.sql` | `74584770d216` | S Realtime publication/identity for E2EE key delivery | Matched |
| `20260730215939_remove_e2ee_restore_messaging.sql` | `978d532d7c46` | Drops/reverts E2EE restore surface; P/F/G cleanup | Matched |
| `20260730221054_add_messaging_poll_votes.sql` | `563c03e96750` | T messaging poll votes; F/P/Tr/I/G | Local-only |
| `20260730221635_repair_app_presence_authorization.sql` | `eac28d03fae9` | P/F repair Realtime presence authorization | Local-only |
| `20260731090000_realtime_post_comments.sql` | `0bf483ae509c` | S add `post_comments` to Realtime publication/identity | Local-only |
| `20260731090921_add_singleton_app_admin.sql` | `3181db0f3daa` | C singleton admin constraint/index; F/Tr | Matched |
| `20260731091024_allow_platform_admin_signup_email.sql` | `f917537ee79b` | F/P allow platform-admin signup email | Matched |
| `20260731091321_grant_app_admin_service_access.sql` | `ef41ba4f942a` | G service access to app-admin objects/functions | Matched |
| `20260731091435_grant_club_provisioning_service_access.sql` | `5a5041ca00c6` | G club provisioning service access | Matched |
| `20260731100048_grant_platform_admin_content_moderation.sql` | `3d28cc6a6cfd` | F/P platform-admin visibility/deletion moderation | Local-only |
| `20260731122448_add_chat_message_delete_policies.sql` | `48d157a041b4` | P direct/group message delete policies | Matched |
| `20260731130000_allow_group_members_to_leave.sql` | `acd87cb8eb3c` | P/F allow group member self-leave | Local-only |
| `20260731132000_add_group_chat_admin_deletion.sql` | `d8a057366ec8` | F/P group-admin chat deletion | Local-only |
| `20260731140000_add_chat_attachment_storage.sql` | `f5a9a5e82247` | S private `chat-attachments` bucket and object policies; G | Local-only |
| `20260731150000_repair_chat_attachment_read_policy.sql` | `6c2c303f18c3` | P repair uploader/member attachment reads | Local-only |
| `20260731151000_add_group_photo_select_policy.sql` | `6f83a405728f` | P creator/member SELECT on group photos | Local-only |
| `20260731153000_group_chat_notification_grouping.sql` | `ac4db48d88e0` | F notification grouping/copy for group chat | Local-only |
| `20260731170859_allow_club_accounts_to_view_all_feeds.sql` | `b6b1aa671c7c` | F/P expand club-account feed visibility | Matched |
| `20260731183116_repair_platform_admin_content_deletion.sql` | `55bb76f15fe1` | P repair platform-admin content deletion | Matched |
| `20260801085833_fix_notification_club_id_ambiguity.sql` | `90005da5f1eb` | F fix notification `club_id` ambiguity | Matched |
| `20260801090000_allow_platform_admin_moderation_report_reads.sql` | `32f58fa83683` | P/G platform-admin moderation-report SELECT | Local-only |
| `20260801090715_grant_post_comments_delete.sql` | `dc5ec64a724a` | G/P grant comment deletion | Matched |
| `20260801100000_harden_chat_notification_privacy.sql` | `7ce48a2966d9` | F/P prevent private chat notification leakage | Local-only |
| `20260801120000_add_user_last_seen.sql` | `c32172f81bc3` | C profile last-seen; F/Tr/I/G | Local-only |
| `20260803120000_club_room_board_and_chat_lanes.sql` | `5550d5f50634` | P split board/chat write/delete lanes; F/G | Local-only |
| `20260803170000_repair_chat_attachment_storage_policies.sql` | `74a147307c03` | P repair all chat attachment storage policies | Local-only |
| `20260803182859_add_account_preferences.sql` | `313f8ff878fb` | T/C account preferences; F/P/Tr/I/G | Matched |
| `20260803193000_fix_chat_media_notification_previews.sql` | `e3f08b70ee16` | F safe chat-media notification previews | Local-only |
| `20260803200000_quiet_club_chat_notifications.sql` | `b27dc312f2ad` | F suppress/quiet club-chat notifications | Local-only |
| `20260804113654_add_app_update_config.sql` | `7aea1650c993` | T app update config; F/P/I/G | Matched |
| `20260804130000_restrict_club_general_chat_to_board.sql` | `ae79e490036d` | P board-only general-chat insertion | Local-only |
| `20260806065804_add_onboarding_version.sql` | `9066f3cd6bf0` | C/F onboarding version state | Matched |
| `20260807100000_add_linked_board_account_context.sql` | `1fe33818daf5` | T `club_account_contexts`; C post/event author linkage; F/P/Tr/I/G/S path policies | Local-only |
| `20260808191441_repair_terms_acceptance_service_role_access.sql` | `d0ecba38f2e2` | G/P repair service-role terms access | Matched |
| `20260808191540_ensure_terms_acceptance_service_role_table_insert.sql` | `f89676fa6f8d` | G ensure service-role terms insert | Matched |
| `20260810174445_add_persistent_tutorial_completion.sql` | `22eb78ed8f1d` | C profile tutorial completion; F/G | Local-only |
| `20260812090926_secure_auth_challenges.sql` | `de2f13681fd1` | C harden public auth challenge tables; F secure challenge RPCs; P/I/G | Local-only |
| `20260812090933_secure_event_checkins_and_polls.sql` | `4a282f5b7cfe` | T/C repair check-ins/polls; F private actor/binding helpers; P/Tr/I/G | Local-only |
| `20260812090936_protect_profile_emails.sql` | `7710ea3854ce` | F private profile-email RPCs; G/revokes email access | Local-only |
| `20260812105930_application_rate_limits.sql` | `353efade34b7` | T private rate rules/buckets/events; F consume/enforce/cleanup RPCs; I/G | Local-only |
| `20260812114050_restore_legacy_auth_compatibility.sql` | `ec8b66494f76` | F six legacy auth compatibility functions; G | Local-only |
| `20260812114051_restore_authenticated_profile_email_visibility.sql` | `9197ccbe0d90` | G column-level profile SELECT excluding test flag; restore authenticated email visibility | Local-only |
| `20260812114104_create_v2_auth_challenges.sql` | `752ad7e76fea` | T private signup/reset v2 challenges; F eight v2 RPCs; I/G | Local-only |
| `20260812121348_create_v2_checkins_and_polls.sql` | `e93a7648ac2c` | F five check-in/poll v2 RPCs; G | Local-only |
| `20260812123921_feed_v2_architecture.sql` | `07cb13a4fbec` | C `club_posts.is_announcement`; F `get_feed_page_v2`; I feed index; G | Local-only |
| `20260812140253_chat_v2_architecture.sql` | `f83d0ead78e2` | T chat change-log/read-state; F thirteen RPCs; P4/Tr6/I8/G/S Realtime | Local-only |
| `20260813101441_notification_v2_outbox.sql` | `e623c5a8d26c` | T outbox/recipients/deliveries; C pipeline version; F12/P/Tr9/I4/G | Local-only |
| `20260813104017_transactional_writes_storage_lifecycle.sql` | `2b0ee8070e6d` | T storage cleanup queue; F twelve transactional/storage RPCs; I/G | Local-only |
| `20260813115049_enable_chat_video_media_contract.sql` | `0ca1ea6e2d9b` | S expand `chat-attachments` MIME contract to video | Local-only |
| `20260813121253_repair_reproducible_schema_permissions.sql` | `1ff71c9e91ae` | G private schema/service grants and sequence grants; P interest/comment fixes; F volatility/Vault dispatch/profile repair | Local-only |

## Actual production schema versus reproducible local final

| Surface | Production evidence | Local final difference | Assessment |
|---|---|---|---|
| Tables | 46 public; no application tables in `private` | 52 public plus 5 private v2/rate-limit tables | 11 expected tables absent |
| Columns | `club_posts.is_announcement` and `notifications.pipeline_version` absent; `post_comments.parent_comment_id` absent; production has extra `post_comments.updated_at`; `event_checkins.checked_in_by` is non-null and lacks local `legacy_checked_in_by` | Canonical local types expect the inverse differences | Partial/conflicting historical state |
| Constraints | Secure check-in and poll constraints are present; no v2 constraints because v2 tables are absent | V2 constraints expected | Baseline secure, v2 absent |
| Indexes | 136 public indexes; v2/rate/feed indexes absent; several legacy indexes are semantically covered under different names | V2 indexes expected | Legacy mostly equivalent, v2 absent |
| Functions/RPCs | 44 app functions in public/private catalog; generated API types expose 13 functions | Local parser finds 105 app functions; generated types expose 58 | 45 exposed RPCs missing, chiefly v2/compatibility |
| Triggers | 22 public triggers | 28 expected | Six Chat-v2 journaling triggers absent |
| RLS policies | 155; all 46 public tables have RLS enabled | 160 expected | V2 policies absent; several historical name/semantic drifts |
| Grants | Secure email restriction is active; `service_role` lacks final `private` schema usage; v2 grants absent | Reproducibility repair and compatibility grants expected | Repair absent |
| Storage | Six expected buckets exist; `chat-attachments` is private, 10 MiB, image-only; live uploader-read policy exists | Video MIME types and one group-photo SELECT policy expected | Partial |
| Realtime | 11 tables published | `club_followers` and Chat-v2 change log additionally expected | Partial |

Production Realtime members are `club_channel_messages`, `club_channel_poll_votes`, `club_inbox_messages`, `club_inbox_threads`, `direct_messages`, `group_chat_members`, `group_chats`, `group_message_receipts`, `group_messages`, `notifications`, and `post_comments`. `club_followers` has default rather than full replica identity.

The three production aggregate views use `security_invoker=true` and match the expected aggregate behavior. All existing public application tables have RLS enabled.

## Remote-only migration mapping

Classification vocabulary here is effect-based: **Renamed equivalent**, **Archived/consolidated**, **Source drift**, or **Equivalent with later live repair**.

| Remote Version | Remote Effect | Equivalent Local Migration(s) | Classification | Confidence |
|---|---|---|---|---|
| `20260726194807` | Test-club visibility | archived duplicate `007_test_club_visibility.sql`; consolidated `007_legacy_features.sql` | Archived/consolidated | High |
| `20260726195007` | Protect profile test flag | archived `008_protect_profile_test_flag.sql`; consolidated `008_legacy_features.sql` | Archived/consolidated | High |
| `20260726204046` | Security/performance hardening | `011_security_performance_hardening.sql` | Renamed equivalent | High |
| `20260726204556` | Final RLS hardening | `012_finalize_rls_hardening.sql` | Renamed equivalent | High |
| `20260730112835` | Direct messages | `004_direct_messages.sql` | Renamed equivalent | High |
| `20260730112843` | DM delivery status | archived `005_direct_message_delivery_status.sql`; consolidated `005_legacy_features.sql` | Archived/consolidated | High |
| `20260730112847` | Group chats | archived `007_group_chats.sql`; consolidated `007_legacy_features.sql` | Archived/consolidated | High |
| `20260730112850` | Group chat photos | archived `008_group_chat_photos.sql`; consolidated `008_legacy_features.sql` | Archived/consolidated | High |
| `20260730112854` | Group member order | `009_group_member_order.sql` | Renamed equivalent | High |
| `20260730112857` | Push devices | `20260730110505_add_push_devices.sql` | Renamed equivalent | High |
| `20260730112928` | Notification delivery pipeline | `20260730112513_add_notification_delivery_pipeline.sql` | Source drift: remote has older dispatcher; later forward repair supersedes it | High |
| `20260730113030` | Notification inbox hardening | `20260730113012_harden_notification_inbox.sql` | Renamed equivalent | High |
| `20260730113138` | Chat policy hardening | `20260730113110_harden_chat_policies.sql` | Renamed equivalent | High |
| `20260730121935` | Notification copy | `20260730121836_improve_notification_copy.sql` | Renamed equivalent | High |
| `20260730123011` | Localized push notifications | `20260730122711_localize_push_notifications.sql` | Renamed equivalent | High |
| `20260731131818` | Group members may leave | `20260731130000_allow_group_members_to_leave.sql` | Renamed equivalent | High |
| `20260731131831` | Group admin deletion | `20260731132000_add_group_chat_admin_deletion.sql` | Renamed equivalent | High |
| `20260731133956` | Chat attachment storage | `20260731140000`; repaired by `20260731150000` / `20260803170000` | Equivalent with later live repair; remote source omitted uploader-read policy but live schema has it | High |
| `20260731213556` | Messaging poll votes | `20260730221054_add_messaging_poll_votes.sql` | Renamed equivalent | High |
| `20260731213605` | App-presence authorization | `20260730221635_repair_app_presence_authorization.sql` | Renamed equivalent | High |
| `20260731215608` | Admin moderation-report reads | `20260801090000_allow_platform_admin_moderation_report_reads.sql` | Semantic equivalent; local adds comments only | High |
| `20260803123933` | Group message receipts | archived `010_group_message_receipts.sql`; consolidated `010_legacy_features.sql` | Archived/consolidated; reference-data portion needs separate verification | Medium |
| `20260804075145` | Chat media notification previews | `20260803193000_fix_chat_media_notification_previews.sql` | Renamed equivalent | High |
| `20260812072251` | Realtime post comments | `20260731090000_realtime_post_comments.sql` | Renamed equivalent | High |
| `20260812072257` | Group notification grouping | `20260731153000_group_chat_notification_grouping.sql` | Renamed equivalent | High |
| `20260812072304` | Chat notification privacy | `20260801100000_harden_chat_notification_privacy.sql` | Renamed equivalent | High |
| `20260812072320` | User last seen | `20260801120000_add_user_last_seen.sql` | Renamed equivalent | High |
| `20260812072325` | Quiet club chat notifications | `20260803200000_quiet_club_chat_notifications.sql` | Renamed equivalent | High |
| `20260812072330` | Persistent tutorial completion | `20260810174445_add_persistent_tutorial_completion.sql` | Renamed equivalent | High |
| `20260812104007` | Secure auth challenges | `20260812090926_secure_auth_challenges.sql` | Renamed equivalent | High |
| `20260812104012` | Secure event check-ins and polls | `20260812090933_secure_event_checkins_and_polls.sql` | Equivalent secure behavior; inherited column shape differs | High effect / Medium shape |
| `20260812104017` | Protect profile emails | `20260812090936_protect_profile_emails.sql` | Renamed equivalent | High |

No remote-only version remains without an effect mapping. “Unresolved” still applies to the safe reconciliation action for remote `20260803123933` because its local consolidated file includes reference-data writes that this schema-only audit intentionally did not inspect.

## Local-only migration classification

Classes: **A** truly pending; **B** already represented remotely; **C** superseded; **D** bootstrap/fresh-install only; **E** conflict/manual review. Actions are recommendations only and were not executed. “Mark-applied” always means a future history-only reconciliation after preserving evidence; it never means execute the SQL.

| Local Version | Effect | Present in Production? | Class | Future action |
|---|---|---:|:---:|---|
| `00000000000000` | Core bootstrap | Yes, but not byte-identical | D | History-reconcile only; never execute on production |
| `001` | Post comments | Partial | E | Manual: resolve parent thread column, extra `updated_at`, and local SQL/generated-type FK mismatch |
| `002` | Original event check-ins | Superseded | C | Skip historical SQL; secure remote baseline owns current shape |
| `003` | Original polls + announcement flag | Partial/superseded | C | Skip historical SQL; secure polls exist, add announcement only through Feed-v2 forward migration |
| `004` | Direct messages | Yes | B | Mark-applied only after archiving match to remote `20260730112835` |
| `005` | DM delivery/moderation/blocks | Yes | B | Mark-applied after component mapping is preserved |
| `006` | Club blocks + presence + follower Realtime | Partial | E | Manual forward repair for follower publication/replica identity; do not replay whole file |
| `007` | Group chat + test visibility | Yes | B | Mark-applied after archived/consolidated mapping |
| `008` | Group photo + test flag | Yes | B | Mark-applied after archived/consolidated mapping |
| `009` | Group member order | Yes | B | Mark-applied against remote `20260730112854` |
| `010` | Group receipts + academic-year reference data | Schema yes; data unverified | E | Manual: verify reference-data effect separately before history action |
| `011` | Security/performance hardening | Yes | B | Mark-applied against remote `20260726204046` |
| `012` | Final RLS hardening | Yes | B | Mark-applied against remote `20260726204556` |
| `013` | Public event images | Yes | B | Mark-applied after bucket evidence capture |
| `014` | Terms acceptance | Yes | B | Mark-applied; live schema and later matched repairs establish presence |
| `20260730110505` | Push devices | Yes | B | Mark-applied against remote `20260730112857` |
| `20260730112513` | Notification delivery pipeline | Yes, source differs | B | Archive exact remote SQL; mark local represented; do not replay embedded dispatcher |
| `20260730113012` | Notification inbox hardening | Yes | B | Mark-applied against remote `20260730113030` |
| `20260730113110` | Chat policy hardening | Yes | B | Mark-applied against remote `20260730113138` |
| `20260730121836` | Notification copy | Yes | B | Mark-applied against remote `20260730121935` |
| `20260730122711` | Localized push | Yes | B | Mark-applied against remote `20260730123011` |
| `20260730221054` | Messaging poll votes | Yes | B | Mark-applied against remote `20260731213556` |
| `20260730221635` | Presence authorization repair | Yes | B | Mark-applied against remote `20260731213605` |
| `20260731090000` | Realtime post comments | Yes | B | Mark-applied against remote `20260812072251` |
| `20260731100048` | Admin content moderation/visibility | Partial, later superseded | C | Skip historical; preserve current later policies and make inactive-club visibility a product decision |
| `20260731130000` | Group member leave | Yes | B | Mark-applied against remote `20260731131818` |
| `20260731132000` | Group admin deletion | Yes | B | Mark-applied against remote `20260731131831` |
| `20260731140000` | Chat attachment storage | Yes after later repair | B | Mark represented; archive remote source variant |
| `20260731150000` | Attachment read repair | Yes, outside matching history | B | Mark-applied only with live-state evidence |
| `20260731151000` | Group photo SELECT policy | No | A | Do not replay out of order; create a new forward migration after policy review |
| `20260731153000` | Group notification grouping | Yes | B | Mark-applied against remote `20260812072257` |
| `20260801090000` | Moderation-report reads | Yes | B | Mark-applied against remote `20260731215608` |
| `20260801100000` | Chat notification privacy | Yes | B | Mark-applied against remote `20260812072304` |
| `20260801120000` | User last seen | Yes | B | Mark-applied against remote `20260812072320` |
| `20260803120000` | Board/chat lanes | Partial/conflicting | E | Manual: production delete policy is board-only while local final permits follower self-delete |
| `20260803170000` | Attachment policy repair | Yes, outside matching history | B | Mark-applied only with live-state evidence |
| `20260803193000` | Media preview fix | Yes | B | Mark-applied against remote `20260804075145` |
| `20260803200000` | Quiet club notifications | Yes | B | Mark-applied against remote `20260812072325` |
| `20260804130000` | Board-only general-chat insert | Yes | B | Mark-applied; keep separate from unresolved delete semantics |
| `20260807100000` | Linked board account context | Yes, outside matching history | B | Mark-applied only after recording full live object proof |
| `20260810174445` | Tutorial completion | Yes | B | Mark-applied against remote `20260812072330` |
| `20260812090926` | Secure auth challenges | Yes | B | Mark-applied against remote `20260812104007` |
| `20260812090933` | Secure check-ins/polls | Yes, shape variation | B | Mark represented; document inherited column-shape variation |
| `20260812090936` | Protect profile emails | Yes | B | Mark-applied against remote `20260812104017` |
| `20260812105930` | Rate limits | No | A | Apply later in ordered forward wave |
| `20260812114050` | Legacy auth compatibility | No | A | Apply later after baseline verification |
| `20260812114051` | Restore authenticated profile email visibility | No | A | Apply later only after confirming intended privacy contract |
| `20260812114104` | Auth challenge v2 | No | A | Apply later after rate-limit dependency |
| `20260812121348` | Check-in/poll v2 RPCs | No | A | Apply later after secure baseline and rate limits |
| `20260812123921` | Feed v2 | No | A | Apply later; supplies missing announcement column |
| `20260812140253` | Chat v2 | No | A | Apply later; includes tables/RPCs/triggers/indexes/Realtime |
| `20260813101441` | Notification v2 | No | A | Apply later after prerequisite v2 surfaces |
| `20260813104017` | Transactional/storage v2 | No | A | Apply later after its dependencies |
| `20260813115049` | Media v2 MIME contract | No | A | Apply later after application/client readiness |
| `20260813121253` | Reproducibility repair | No | A | Apply last in migration wave after staging validation and dependency checks |

Totals: **12 A**, **35 B**, **3 C**, **1 D**, **4 E** = **55 local-only migrations**.

The “mark-applied” recommendations are not a blanket authorization. Each must be converted into a reviewed reconciliation manifest containing local fingerprint, remote source digest, catalog evidence, and reviewer approval.

## Current v2 status

| Area | Production status | Evidence |
|---|---|---|
| Auth v1 corrective baseline (`20260812090926`,`...0936`) | Already equivalent | Remote renamed rows exist; secure challenge RPCs and email restriction are live |
| Auth compatibility/email restoration (`...114050`,`...114051`) | Absent | Legacy compatibility RPCs absent; authenticated profile email remains unavailable |
| Auth v2 (`...114104`) | Absent | Both private v2 tables and eight v2 RPCs absent |
| F2/F3 secure corrective (`...090933`) | Already equivalent with shape variation | Secure policies/triggers/constraints live; inherited check-in columns differ |
| F2/F3 v2 (`...121348`) | Absent | Five v2 RPCs absent |
| Rate limits (`...105930`) | Absent | No private rate-limit tables/functions |
| Feed v2 (`...123921`) | Absent | `is_announcement`, feed RPC, and feed index absent |
| Chat v2 (`...140253`) | Absent | Two tables, thirteen functions, six triggers, eight indexes, and Realtime member absent |
| Notification v2 (`20260813101441`) | Absent | Three tables, pipeline column, functions, triggers, and indexes absent |
| Transactional/Storage v2 (`...104017`) | Absent | Cleanup queue and transactional/storage RPCs absent |
| Media v2 (`...115049`) | Absent | Attachment bucket accepts image MIME types only, not video |
| Reproducibility repair (`...121253`) | Absent | `service_role` lacks private-schema use; final grants/function repairs not live; dispatcher remains older variant |

“Absent” means the migration's defining objects/behavior were not found. It does not mean the migration is approved for immediate execution.

## Bootstrap decision

`00000000000000_core_schema_bootstrap.sql` is a fresh-install reconstruction artifact. Production already has the core schema, with historical drift in policy names/path conventions and later object evolution. Executing the bootstrap against production would mix bootstrap assumptions with a mature live schema.

Decision:

- **History-reconciled only**, after the reconciliation manifest is approved.
- **Never execute against existing production.**
- Do not mark it applied until unresolved classes E are settled and a verified recovery checkpoint exists.

## Exact safest future repair sequence

No step below should begin until the recovery gate is satisfied.

1. Freeze this audit snapshot: export the 51-row remote history including statement digests, the 74 local normalized fingerprints, and the production catalog snapshot into a reviewed reconciliation manifest. Do not store embedded credentials from historical SQL; redact and rotate any credential discovered there.
2. Add an immutable archive mapping for all 32 remote timestamped sources. Preserve their original remote version/name/digest and point each to the local/archived semantic equivalent. Do not rewrite production history yet.
3. Resolve the four E rows:
   - `001`: choose the canonical post-comment thread/update/FK shape and fix the local SQL-versus-generated-types discrepancy.
   - `006`: decide and implement a new forward-only `club_followers` Realtime/replica-identity repair if presence needs it.
   - `010`: verify academic-year reference-data semantics with separately approved data reads; do not replay the consolidated file.
   - `20260803120000`: choose board-only versus follower-own-delete semantics and encode the choice in a new forward migration.
4. Create new forward migrations for legacy missing effects (`20260731151000` group-photo SELECT and any approved E-row repairs). Never insert these old files into the middle of production execution order.
5. In a disposable or staging project restored from the production checkpoint, rehearse history-only reconciliation for the 33 B rows, the 2 C rows as skipped/superseded, and bootstrap as D. Confirm that no history operation executes SQL. Keep A rows pending.
6. Recompute a schema diff after reconciliation. It must show only the reviewed A migrations and newly authored forward repairs—not unexplained legacy drift.
7. Apply the A migrations to staging in dependency order: rate limits; auth compatibility/profile grant; auth-v2; F2/F3-v2; Feed-v2; Chat-v2; Notification-v2; transactional/storage-v2; Media-v2; reproducibility repair. Include the new legacy forward repairs at their reviewed dependency points.
8. Run security and behavior verification in staging: RLS by anon/authenticated/service roles, function `search_path`/volatility, grants, trigger side effects, Realtime membership, storage MIME/policies, notification dispatch configuration, and app backward compatibility.
9. Take a fresh verified production recovery checkpoint, record its restore boundary, then repeat the approved history-only reconciliation and only the proven forward migrations in a controlled maintenance window.
10. Re-export and diff the final production schema. Only after database parity and application compatibility are proven should matching Edge Functions be deployed as a separate, rollback-aware change.

Do not use `migration repair` as a substitute for the manifest or for resolving E rows. Do not replay historical local SQL merely to make version lists line up.

## Recovery gate

Current backup metadata:

| Property | Value |
|---|---|
| Region | `eu-central-1` |
| WAL-G enabled | Yes |
| PITR enabled | No |
| Listed backups | None |
| Verified restore checkpoint | None |

WAL-G being enabled, without a listed and tested restore point or PITR, is not a sufficient recovery guarantee.

Minimum capability required before any production mutation:

1. Either PITR enabled and validated to cover the immediate pre-change timestamp, **or** a fresh full logical/physical backup with a visible, immutable restore identifier.
2. A restore rehearsal into an isolated project/environment proving schema, migration history, Auth/Storage metadata needed by the application, and critical data can be recovered.
3. Confirmed operator permissions, documented restore runbook, expected RPO/RTO, and named rollback decision owner.
4. A recorded pre-change catalog/history snapshot and an application/Edge Function version that can operate against the restored database state.

Until those conditions are met, production mutations must remain blocked.

## Final verdict

Four migration-history actions remain manual/unresolved, the v2 forward set is genuinely pending, and the recovery gate is not met.

**MIGRATION HISTORY STILL UNRESOLVED — DO NOT DEPLOY**
