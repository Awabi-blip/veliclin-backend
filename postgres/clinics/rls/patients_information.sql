ALTER TABLE patients_information ENABLE ROW LEVEL SECURITY;

drop policy clinic_staff_view_their_patients 
on patients_information

create policy clinic_staff_view_their_patients 
on patients_information
for select to public 
using (
    exists (
        select 1 from staffs_in_clinics, clinics where 
        patients_information.clinic_id     = staffs_in_clinics.clinic_id 
        and patients_information.clinic_id = clinics.clinic_id
        and staffs_in_clinics.staff_id     = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role   = 'Doctor'::e_staff_role
        and clinics.all_visibility         = true
    )
    or
    exists (
        select 1 from staffs_in_clinics, clinics where
        patients_information.clinic_id    = clinics.clinic_id
        and staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role  = 'Doctor'::e_staff_role
        and clinics.all_visibility        = false
    )
    or 
    exists (
        select 1 from referrals, staffs_in_clinics where
        staffs_in_clinics.staff_id       = referrals.reffered_to
        and referrals.patient_id         = patients_information.patient_id
        and referrals.reffered_to        = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role = 'Doctor'::e_staff_role
    )
    or
    exists (
        select 1 from appointments, patients_in_clinics
        where patients_information.patient_id = appointments.patient_id
        and   patients_information.patient_id = patients_in_clinics.patient_id
        and   patients_in_clinics.added_by    = appointments.doctor_id
        and   patients_in_clinics.added_by    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    )
);


drop policy clinic_staff_view_their_patients 
on patients_information


create policy clinic_staff_view_their_patients 
on patients_information
for insert to public 
with check (
    exists (
        select 1 from staffs_in_clinics, clinics where 
        patients_information.clinic_id     = staffs_in_clinics.clinic_id 
        and patients_information.clinic_id = clinics.clinic_id
        and staffs_in_clinics.staff_id     = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role   = 'Doctor'::e_staff_role
        and clinics.all_visibility         = true
    )
    or
    exists (
        select 1 from staffs_in_clinics, clinics where
        patients_information.clinic_id    = clinics.clinic_id
        and staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role  = 'Doctor'::e_staff_role
        and clinics.all_visibility        = false
    )
    or 
    exists (
        select 1 from referrals, staffs_in_clinics where
        staffs_in_clinics.staff_id       = referrals.reffered_to
        and referrals.patient_id         = patients_information.patient_id
        and referrals.reffered_to        = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role = 'Doctor'::e_staff_role
    )
    or
    exists (
        select 1 from appointments, patients_in_clinics
        where patients_information.patient_id = appointments.patient_id
        and   patients_information.patient_id = patients_in_clinics.patient_id
        and   patients_in_clinics.added_by    = appointments.doctor_id
        and   patients_in_clinics.added_by    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    )
);



create policy clinic_staff_view_their_patients 
on patients_information
for update to public 
using (
    exists (
        select 1 from staffs_in_clinics, clinics where 
        patients_information.clinic_id     = staffs_in_clinics.clinic_id 
        and patients_information.clinic_id = clinics.clinic_id
        and staffs_in_clinics.staff_id     = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role   = 'Doctor'::e_staff_role
        and clinics.all_visibility         = true
    )
    or
    exists (
        select 1 from staffs_in_clinics, clinics where
        patients_information.clinic_id    = clinics.clinic_id
        and staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role  = 'Doctor'::e_staff_role
        and clinics.all_visibility        = false
    )
    or 
    exists (
        select 1 from referrals, staffs_in_clinics where
        staffs_in_clinics.staff_id       = referrals.reffered_to
        and referrals.patient_id         = patients_information.patient_id
        and referrals.reffered_to        = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role = 'Doctor'::e_staff_role
    )
    or
    exists (
        select 1 from appointments, patients_in_clinics
        where patients_information.patient_id = appointments.patient_id
        and   patients_information.patient_id = patients_in_clinics.patient_id
        and   patients_in_clinics.added_by    = appointments.doctor_id
        and   patients_in_clinics.added_by    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    )
);



create policy clinic_staff_view_their_patients 
on patients_information
for delete to public 
using (
    exists (
        select 1 from staffs_in_clinics, clinics where 
        patients_information.clinic_id = staffs_in_clinics.clinic_id 
        and patients_information.clinic_id = clinics.clinic_id
        and staffs_in_clinics.staff_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role = 'Doctor'::e_staff_role
        and clinics.all_visibility = true
    )
    or
    exists (
        select 1 from staffs_in_clinics, clinics where
        patients_information.clinic_id    = clinics.clinic_id
        and staffs_in_clinics.staff_id    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role  = 'Doctor'::e_staff_role
        and clinics.all_visibility        = false
    )
    or 
    exists (
        select 1 from referrals, staffs_in_clinics where
        staffs_in_clinics.staff_id = referrals.reffered_to
        and referrals.patient_id = patients_information.patient_id
        and referrals.reffered_to = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role = 'Doctor'::e_staff_role
    )
    or
    exists (
        select 1 from appointments, patients_in_clinics
        where patients_information.patient_id = appointments.patient_id
        and   patients_information.patient_id = patients_in_clinics.patient_id
        and   patients_in_clinics.added_by    = appointments.doctor_id
        and   patients_in_clinics.added_by    = NULLIF(current_setting('myapp.user_id', true), '')::uuid
    )
    or exists (
        select 1
        from staffs_in_clinics
        where patients_information.clinic_id = staffs_in_clinics.clinic_id
        and staffs_in_clinics.staff_id = NULLIF(current_setting('myapp.user_id', true), '')::uuid
        and staffs_in_clinics.staff_role in ('Doctor'::e_staff_role, 'Manager'::e_staff_role,
        'Receptionist'::e_staff_role)
    )
);

