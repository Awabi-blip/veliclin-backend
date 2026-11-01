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

# needs policy for selecting and inserting staff.

create policy owner_see_all_staff_clinic_ops 
on staffs_in_clinics
for select
using (
   exists (select 1 from clinics where 
   clinics.owner_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
   and 
   clinics.clinic_id = staffs_in_clinics.clinic_id)
);

create policy owner_insert_staffs_in_clinics
on staffs_in_clinics
for insert
with check (
   
   exists (select 1 from clinics where 
   clinics.owner_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
   and 
   clinics.clinic_id = staffs_in_clinics.clinic_id)
);


create view view_patients_as_doctors
with (security_invoker = true) as
select 
    pic.patient_id        as patient_id,
    concat(pic.first_name, ' ', 
    pic.last_name)        as full_name,
    pic.contact_number      as phone_number,
    pic.email             as email,
    pic.gender            as gender,
    pin.neurotype         as neurotype,
    pin.blood_type        as blood_type,
    pin.height_cm         as height_cm,
    pin.weight_kg         as weight_kg,
    pin.note              as note
from      patients_in_clinics  as pic
left join patients_information as pin
on   pic.patient_id       = pin.patient_id;

create view view_patients_as_staff
with (security_invoker = true) as
select 
    pic.patient_id        as patient_id,
    concat(pic.first_name, ' ', 
    pic.last_name)        as full_name,
    pic.contact_number      as phone_number,
    pic.email             as email,
    pic.gender            as gender
from patients_in_clinics  as pic;