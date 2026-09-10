--current user should be staff in the clinic
--doctor should exist in the same clinic with doctor role

drop policy insert_patients_policy_with_doctor on patients_in_clinics;


create policy insert_patients_policy_with_doctor 
on patients_in_clinics 
for insert 
with check (
    exists (
    select 1 from clinics, staffs_in_clinics as sic, staffs_in_clinics as dic
    where clinics.clinic_id = patients_in_clinics.clinic_id
    and   sic.clinic_id     = patients_in_clinics.clinic_id
    and   sic.staff_id      = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    and   sic.staff_role    in ('Doctor'::e_staff_role, 'Manager'::e_staff_role,
         'Receptionist'::e_staff_role)
    and   sic.is_active     = true)
);


drop policy select_patients_policy_with_doctor
on patients_in_clinics;

create policy select_patients_policy_with_doctor 
on patients_in_clinics 
for select 
using (
    exists (select 1 from clinics, staffs_in_clinics as sic
    where clinics.clinic_id = patients_in_clinics.clinic_id
    and   sic.clinic_id     = patients_in_clinics.clinic_id
    and   sic.staff_id      = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    and   sic.staff_role    in ('Doctor'::e_staff_role, 'Manager'::e_staff_role,
         'Receptionist'::e_staff_role)
    and   sic.is_active     = true

    )
);

drop policy update_patients_policy_with_doctor 
on patients_in_clinics

create policy update_patients_policy_with_doctor 
on patients_in_clinics
for update 
using (
    exists (select 1 from clinics, staffs_in_clinics as sic, staffs_in_clinics as dic
    where clinics.clinic_id = patients_in_clinics.clinic_id
    and   sic.clinic_id     = patients_in_clinics.clinic_id
    and   sic.staff_id      = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    and   sic.staff_role    in ('Doctor'::e_staff_role, 'Manager'::e_staff_role,
         'Receptionist'::e_staff_role)
    and   sic.is_active     = true
    )
);

drop policy delete_patients_policy_with_doctor 
on patients_in_clinics;

create policy delete_patients_policy_with_doctor 
on patients_in_clinics
for delete 
using (
    exists (select 1 from clinics, staffs_in_clinics as sic, staffs_in_clinics as dic
    where clinics.clinic_id = patients_in_clinics.clinic_id
    and   sic.clinic_id     = patients_in_clinics.clinic_id
    and   sic.staff_id      = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    and   sic.staff_role    in ('Doctor'::e_staff_role, 'Manager'::e_staff_role,
         'Receptionist'::e_staff_role)
    and   sic.is_active     = true
    )

);

search_path = public, pg_temp

REVOKE CREATE ON SCHEMA public FROM app;

select * from patients_in_clinics;
select * from staffs_in_clinics;



doctor_id = 019f8cbb-caf8-7fb4-99e4-88421e1167c2
manager_id = 019f8caa-a51a-7e7f-8208-403bc23616b8

set role app;

SET myapp.user_id TO '019f8cbb-caf8-7fb4-99e4-88421e1167c2';

CALL add_patients_to_clinics(
    '019f8cbb-caf8-7fb4-99e4-88421e1167c2'::UUID,  -- doctor_id
    'John',                                   -- first_name
    'Doe',                                    -- last_name
    '+1234567892',                            -- phone_number
    'Male',                                      -- gender
    'john.doe@example.com'                    -- email (optional)
);