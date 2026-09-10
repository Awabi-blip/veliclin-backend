drop function start_appointment();

create or replace function start_appointment(
    f_appointment_id BIGINT
) returns VOID
security definer
as $$
declare 
v_staff_id         uuid                  := current_setting('myapp.user_id');
v_scheduled_at     TIMESTAMPTZ           := (SELECT scheduled_at FROM appointments WHERE id = f_appointment_id);
v_status           E_appointment_status  := (SELECT status FROM appointments WHERE id = f_appointment_id);
v_hour_difference  SMALLINT              := (SELECT (EXTRACT(EPOCH FROM (v_scheduled_at - now()))) / 3600);
BEGIN

    if not exists (SELECT 1 FROM staffs_in_clinics WHERE id = v_staff_id) THEN
        raise exception using 
        errcode = 'P2001',
        message = 'unauthorised';
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