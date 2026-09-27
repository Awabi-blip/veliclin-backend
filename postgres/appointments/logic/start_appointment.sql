-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
drop function start_appointment;
select * from appointments;
SELECT * FROM staffs_in_clinics join app_users on staffs_in_clinics.staff_id = app_users.id

set myapp.user_id = '01a07759-3b0e-7c2a-980d-fe8ee75586d3';
set role postgres;
set role app;
call start_appointment(12)

select * from appointments;

create or replace procedure start_appointment(
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
BEGIN

    if (v_valid_clinic_id is null) 
    or (v_status is null) then
        raise exception using
        errcode = 'P2001',
        message = 'unauthorised for this action';
    end if;
    
    if v_status != 'Scheduled'::e_appointment_status
        then 
        raise exception using 
        errcode = 'P2001',
        message = 'trying to start an appointment which isn''t scheduled';
    end if;

    update appointments
    set  "status" = 'On_going'::e_appointment_status
    where appointment_id = p_appointment_id;

end;
$$ language plpgsql;