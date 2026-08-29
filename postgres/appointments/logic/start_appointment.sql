CREATE OR REPLACE FUNCTION start_appointment(
    f_appointment_id BIGINT
) RETURNS VOID
SECURITY DEFINER
AS $$
DECLARE 
v_staff_id         UUID                := auth.uid();
v_scheduled_at     TIMESTAMPTZ         := (SELECT scheduled_at FROM appointments WHERE id = f_appointment_id);
v_status           E_appointment_status  := (SELECT status FROM appointments WHERE id = f_appointment_id);
v_hour_difference  SMALLINT            := (SELECT (EXTRACT(EPOCH FROM (v_scheduled_at - now()))) / 3600);
BEGIN

    if not exists (SELECT 1 FROM staffs_in_clinics WHERE id = v_staff_id) THEN
        raise exception '';
    end if; 
    
    if v_hour_difference > 2
    then
      raise exception '';
    end if;
    
    if v_status != 'scheduled'
        then 
            raise exception '';
    end if;

    update appointments
    set  "status" = 'on_going'
    where id = f_appointment_id;

end;
$$ language plpgsql;