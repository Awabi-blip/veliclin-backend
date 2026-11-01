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
    or 
    exists ()
);

create policy owner_see_all_staff_clinic_ops 
on staffs_in_clinics
for select
using (
   exists (select 1 from clinics where 
   clinics.owner_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
   and 
   clinics.clinic_id = staffs_in_clinics.clinic_id)
);

select * from clinics;