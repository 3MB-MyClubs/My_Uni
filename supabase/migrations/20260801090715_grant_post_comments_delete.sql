-- Table privileges are required in addition to the row-level delete policy.
-- The policy still limits deletes to the authenticated comment author.

grant delete on table public.post_comments to authenticated;
