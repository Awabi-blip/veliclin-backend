-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
set myapp.user_id = '01a07759-3b0e-7c2a-980d-fe8ee75586d3';
set role app;
set role postgres;
call end_appointment(20);
select * from appointments join patients_in_clinics on appointments.patient_id = patients_in_clinics.patient_id;
select * from appointments;
create or replace procedure end_appointment(
    p_appointment_id BIGINT
)
security definer
as $$
declare 
v_staff_id         uuid                  := current_setting('myapp.user_id');
v_valid_clinic_id  uuid                  := (
                                            select clinic_id
                                            from   staffs_in_clinics
                                            where  staff_id   = v_staff_id
                                            and    staff_role in (
                                                    'Doctor'::e_staff_role,
                                                    'Manager'::e_staff_role,
                                                    'Receptionist'::e_staff_role)
                                                
                                            and    is_active  = true);

v_status           E_appointment_status  := (SELECT status FROM appointments 
                                             WHERE appointment_id = p_appointment_id 
                                             AND   clinic_id      = v_valid_clinic_id);
begin

    if (v_valid_clinic_id is null) 
    or (v_status is null) then
        raise exception using
        errcode = 'P2001',
        message = 'unauthorised for this action';
    end if;

    if v_status != 'On_going'::e_appointment_status
        then 
        raise exception using 
        errcode = 'P2001',
        message = 'trying to end an appointment which isn''t on going';
    end if;
    
    update appointments
    set  "status" = 'Completed'::e_appointment_status
    where appointment_id = p_appointment_id;

end;
$$ language plpgsql