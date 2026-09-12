-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
drop function start_appointment();

create or replace function start_appointment(
    f_appointment_id BIGINT
) returns VOID
security definer
as $$
declare 
v_staff_id         uuid                  := current_setting('myapp.user_id');
v_valid_clinic_id  uuid                  := (
                                            select clinic_id
                                            from   staffs_in_clinics
                                            where  staff_id   = v_staff_id
                                            and  staff_role in (
                                                    'Doctor'::e_staff_role,
                                                    'Manager'::e_staff_role,
                                                    'Receptionist'::e_staff_role
                                                )
                                            and    is_active  = true

);
v_scheduled_at     TIMESTAMPTZ           := (SELECT scheduled_at FROM appointments WHERE id = f_appointment_id);
v_status           E_appointment_status  := (SELECT status FROM appointments WHERE id = f_appointment_id);
v_hour_difference  SMALLINT              := (SELECT (EXTRACT(EPOCH FROM (v_scheduled_at - now()))) / 3600);
BEGIN

    if v_valid_clinic_id is null then
        raise exception using
        errcode = 'P2001',
        message = 'unauthorised for this action';
    end if;

    if v_hour_difference > 2
    then
      raise exception using 
        errcode = 'P2001',
        message = 'hour difference cant be more than 2';
    end if;
    
    if v_status != 'scheduled'
        then 
        raise exception using 
        errcode = 'P2001',
        message = 'trying to start an appointment which isn''t scheduled';
    end if;

    update appointments
    set  "status" = 'on_going'
    where id = f_appointment_id;

end;
$$ language plpgsql;