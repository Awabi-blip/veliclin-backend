-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
-- Active: 1776099699305@@127.0.0.1@5432@cliniqo@public

alter table appointments enable row level security;
set role test;

select * from appointments;

select * from clinics;

set role test;
select * from view_appointments_as_staffs

SELECT
    current_user,
    session_user,
    pg_get_userbyid(c.relowner) AS table_owner,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced,
    r.rolsuper,
    r.rolbypassrls
FROM pg_class c
JOIN pg_roles r
    ON r.rolname = current_user
WHERE c.oid = 'public.appointments'::regclass;

select * from profiles where id = '01a06a69-a3bf-7661-a523-f9386a23180f'::UUID;

SELECT
    clinic_id,
    staff_id,
    staff_role,
    is_active
FROM staffs_in_clinics
WHERE staff_id =
    NULLIF(current_setting('myapp.user_id', true), '')::uuid;
 
 SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'appointments';

SELECT
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'appointments';

SELECT current_setting('myapp.user_id', true);

create policy staffs_see_appointments on appointments
for select to public
using (
    exists (
        select 1 from staffs_in_clinics
        where appointments.clinic_id        = staffs_in_clinics.clinic_id
        and   staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and   staffs_in_clinics.staff_role  in 
        ('Doctor'::e_staff_role,
        'Manager'::e_staff_role)
        and staffs_in_clinics.is_active     = true
    )
);


create policy doctors_manage_appointment_information on appointments_information
for all to public
using (
    exists (
        select 1 from 
        staffs_in_clinics, clinics
        where 
        appointments_information.clinic_id = staffs_in_clinics.clinic_id
        and
        appointments_information.clinic_id = clinics.clinic_id
        and 
        clinics.all_visibility = false
        and
        appointments_information.doctor_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and
        staffs_in_clinics.staff_id         = appointments_information.doctor_id
        and
        staffs_in_clinics.staff_role       = 'Doctor'::e_staff_role
        and staffs_in_clinics.is_active    = true

    )

);

create policy managers_view_appointments_information on appointments_information
for select to public
using(
    exists (
        select 1 from 
        staffs_in_clinics, clinics
        where 
        appointments_information.clinic_id = staffs_in_clinics.clinic_id
        and
        appointments_information.clinic_id = clinics.clinic_id
        and
        clinics.all_visibility = true
        and 
        staffs_in_clinics.staff_id        = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and
        staffs_in_clinics.staff_role in ('Doctor'::e_staff_role, 'Manager'::e_staff_role)
        and staffs_in_clinics.is_active = true

    )
);