ALTER TABLE staffs_in_clinics ENABLE ROW LEVEL SECURITY;


create or replace function my_clinic_ids()
returns setof UUID
language sql
security definer
stable
set search_path = public
as $$
    select clinic_id
    from staffs_in_clinics
    where staff_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
$$;

-- 3. The actual policy
create policy staff_view_same_clinic
on staffs_in_clinics
for select
using (
    clinic_id in (select my_clinic_ids())
);

