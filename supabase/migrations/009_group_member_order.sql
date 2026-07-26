-- Preserve the creator's recipient-selection order for deterministic
-- automatically generated group names on every device.

alter table group_chat_members
  add column if not exists position integer;

with ranked_members as (
  select
    group_id,
    user_id,
    row_number() over (
      partition by group_id
      order by joined_at, user_id
    ) - 1 as member_position
  from group_chat_members
)
update group_chat_members as member
set position = ranked.member_position
from ranked_members as ranked
where member.group_id = ranked.group_id
  and member.user_id = ranked.user_id
  and member.position is null;

alter table group_chat_members
  alter column position set default 0,
  alter column position set not null;

create index if not exists group_chat_members_order_idx
  on group_chat_members (group_id, position, joined_at);
