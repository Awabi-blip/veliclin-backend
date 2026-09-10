
select * from appointments;
set role app;
set role postgres;

call cancel_appointment(2);

create or replace procedure cancel_appointment(
    p_appointment_id bigint
) security definer as $$
declare
    v_staff_id        uuid := current_setting('myapp.user_id')::uuid;
    v_valid_clinic_id uuid := (select clinic_id from staffs_in_clinics where staff_id = v_staff_id
                     and staff_role IN ('Doctor'::e_staff_role, 'Manager'::e_staff_role, 
                    'Receptionist'::e_staff_role));
begin

    if v_valid_clinic_id is null then         
    raise exception using 
        errcode = 'P2001',
        message =  'unauthorised';
    end if;

    -- the clinic_id = v_valid_clinic_id is doing the
    -- heavy lifting here because the schema ensures
    -- the foreign relationship with doctors_in_clinics
    -- so only staff with the matching clinic_id
    -- with the doctors clinic_id can UPDATE

    update appointments
    set status = 'Cancelled'::E_appointment_status
    where appointment_id = p_appointment_id
    and clinic_id = v_valid_clinic_id;

    if not found then
        raise exception using 
        errcode = 'P2001',
        message =  'appointment not found';
    end if;

end;
$$ language plpgsql;

select * from appointments;