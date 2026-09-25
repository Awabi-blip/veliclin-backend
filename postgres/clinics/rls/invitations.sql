
alter table invitations enable row level security;
create policy people_see_their_own_invites on  
invitations for select
using (
    receiver_id = nullif(current_setting('myapp.user_id', true),
    '')::uuid
);

