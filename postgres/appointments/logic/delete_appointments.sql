
select * from appointments;
set role app;
set role postgres;

call cancel_appointment(2);

CREATE OR REPLACE PROCEDURE cancel_appointment(
    p_appointment_id BIGINT
) SECURITY DEFINER AS $$
DECLARE
    v_staff_id        uuid := current_setting('myapp.user_id')::uuid;
    v_valid_clinic_id uuid := (select clinic_id from staffs_in_clinics where staff_id = v_staff_id
                     and staff_role IN ('Doctor'::e_staff_role, 'Manager'::e_staff_role, 
                    'Receptionist'::e_staff_role));
BEGIN

    if v_valid_clinic_id is null 
        then raise exception 'unauthorised';
    end if;

    -- the clinic_id = v_valid_clinic_id is doing the
    -- heavy lifting here because the schema ensures
    -- the foreign relationship with doctors_in_clinics
    -- so only staff with the matching clinic_id
    -- with the doctors clinic_id can UPDATE

    UPDATE appointments
    SET status = 'Cancelled'::E_appointment_status
    WHERE appointment_id = p_appointment_id
    AND clinic_id = v_valid_clinic_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'appointment not found';
    END IF;

END;
$$ LANGUAGE plpgsql;

select * from appointments;