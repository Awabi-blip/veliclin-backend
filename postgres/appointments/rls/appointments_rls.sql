createdr policy staffs_see_appointments on appointments
for select to public
using (
    exists (
        select 1 from staffs_in_clinics
        where appointments.clinic_id        = staffs_in_clinics.clinic_id
        and   staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and   staffs_in_clinics.staff_role  in 
        ('Doctor'::e_staff_role,
        'Manager'::e_staff_role)
        and staffs_in_clinics.is_active = true
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