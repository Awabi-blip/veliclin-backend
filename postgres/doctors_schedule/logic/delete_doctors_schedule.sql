create or replace procedure delete_doctor_schedule(
    p_schedule_id         bigint,
    p_delete_appointments boolean
)
as $$
declare
    -- fetches current_user_id
    v_staff_id        uuid           := current_setting('my_app.user_id')::uuid;
    
    --checks if the clinic exists, where the current_user who is v_staff_id
    --exists
    v_valid_clinic_id uuid           := (
        select clinic_id
        from   staffs_in_clinics
        where  staff_id   = v_staff_id
          and  staff_role in (
              'Doctor'::e_staff_role,
              'Manager'::e_staff_role,
              'Receptionist'::e_staff_role
          )
    );
begin

    if v_valid_clinic_id is null then
        raise exception 'unauthorised';
    end if;

    -- this would only map the correct doctor
    -- the table has the clinic_id
    -- get clinic_id for staff, then update appointment
    -- of that doctor (clinic_id = v_clinic_id)
    if p_delete_appointments = false then
        update doctors_schedule
        set    is_deleted = TRUE
        where  schedule_id = p_schedule_id
        and    clinic_id   = v_valid_clinic_id;

    else
        -- this would only map the correct doctor
        -- the table has the clinic_id
        -- get clinic_id for staff, then update appointment
        -- of that doctor (clinic_id = v_clinic_id)
        update appointments
        set    status = 'cancelled'::e_appointment_status
        where  doctor_schedule_id = p_schedule_id
        and    clinic_id   = v_clinic_id;

        if not found then raise exception
            'the doctor does not belong to your clinic,
             or schedule id was not found';
        end if;


        -- the clinic_id = v_valid_clinic_id is doing the heavy lifting
        -- v_valid_clinic_id is the staff_id
        -- clinic_id is the doctor_id
        update doctors_schedule
        set    is_deleted   = TRUE
        where  schedule_id  = p_schedule_id
        and    clinic_id    = v_valid_clinic_id;

        if not found then raise exception
            'the doctor does not belong to your clinic,
             or schedule id was not found';
        end if;
        
        -- select day_shift_starts, day_shift_ends, time_shift_starts, time_shift_ends
        -- into   v_sdd, v_edd, v_t_s, v_t_e
        -- from   doctors_schedule
        -- where  schedule_id = p_schedule_id
        --   and  clinic_id   = v_valid_clinic_id;

        -- select id into v_s_d
        -- from   lookup_days
        -- where  day = v_sdd;

        -- select id into v_e_d
        -- from   lookup_days
        -- where  day = v_edd; -- BUG: was sdd

        -- delete from appointments
        -- where  extract(isodow from scheduled_at) in (v_s_d, v_e_d)
        --   and  case
        --            when v_t_s < v_t_e then
        --                scheduled_at::time >= v_t_s
        --                and ends_at::time  <= v_t_e
        --            when v_t_s > v_t_e then
        --                scheduled_at::time >= v_t_s
        --                or  ends_at::time  <= v_t_e
        --        end
        --   and  doctor_id = (select doctor_id from doctors_schedule where schedule_id = p_schedule_id)
        --   and  clinic_id = v_valid_clinic_id;

    end if;

end;
$$ language plpgsql;