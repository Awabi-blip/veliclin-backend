-- Active: 1778842009804@@127.0.0.1@5432@cliniqo
create or replace procedure reschedule_appointment(
    p_appointment_id bigint,
    p_scheduled_at   timestamptz,
    p_duration_hours decimal(2, 1),
    p_meeting_link   text default null
)
as $$
declare
    v_staff_id               uuid           := current_setting('myapp.user_id')::uuid;
    v_valid_clinic_id        uuid           := (
        select clinic_id
        from   staffs_in_clinics
        where  staff_id   = v_staff_id
          and  staff_role in (
              'Doctor'::e_staff_role,
              'Manager'::e_staff_role,
              'Receptionist'::e_staff_role
          )
         and is_active = true;
    );

    v_schedule_id            bigint;
    v_doctor_id              uuid;

    v_patient_id             uuid;
    v_ends_at                timestamptz    := p_scheduled_at + (p_duration_hours * interval '1 hour');
    v_appointment_start_day  e_working_days := (
        select day
        from   lookup_days
        where  id = extract(isodow from p_scheduled_at)
    );
    v_appointment_start_time time           := (p_scheduled_at at time zone 'UTC')::time;
    v_appointment_end_time   time           := ((p_scheduled_at at time zone 'UTC') + (p_duration_hours * interval '1 hour'))::time;

begin

    if v_valid_clinic_id is null then
        raise exception 'unauthorised';
    end if; -- BUG: missing end if

    --schema enforces, that doctor_id and clinic_id in appointments
    --exist in the staffs_in_clinics table
    --then when the condition clinic_id = v_valid_clinic_id
    --its to check that clinic_id comes together with the current 
    --staff's clinic_id which is v_valid_clinic_id
    select doctor_id, patient_id
    into   v_doctor_id, v_patient_id
    from   appointments
    where  appointment_id = p_appointment_id
      and  clinic_id      = v_valid_clinic_id;

    if not found then
        raise exception 'appointment not found';
    end if;

    if p_duration_hours not in (0.5, 1, 1.5, 2) then
        raise exception 'invalid duration: must be 0.5, 1, 1.5, or 2 hours';
    end if;

    -- perform pg_advisory_xact_lock(
    --     hashtext(v_doctor_id::text),
    --     hashtext(v_patient_id::text)
    -- ); one doctor can only have one appointment with a doctor so unique index catches this.

    select schedule_id 
    into   v_schedule_id
    from   doctors_schedule
    where  doctor_id = p_doctor_id
        and  (v_appointment_start_day = day_shift_starts
        or   v_appointment_start_day = day_shift_ends)
        and  case
            when time_shift_starts < time_shift_ends then
                v_appointment_start_time >= time_shift_starts
                and v_appointment_end_time <= time_shift_ends

                      
                    --22:00, 10pm      --7:00, 7:00am (9 hours)
            when time_shift_starts > time_shift_ends then
                case                                    
                    when v_appointment_start_time > v_appointment_end_time then
                        v_appointment_start_time >= time_shift_starts
                        and v_appointment_end_time <= time_shift_ends
                            
                            --2:00, 2am                  4:00, 4am       
                    when v_appointment_start_time < v_appointment_end_time then
                        
                            --26:00, or 2am (if we series off 24)           22:00, 10pm                              
                        v_appointment_start_time +INTERVAL '24 hours' >= time_shift_starts
                            --4:00                     7:00am 
                        and v_appointment_end_time <= time_shift_ends      
                end
            end
    for update;


    update appointments
    set    scheduled_at   = p_scheduled_at,
           ends_at        = v_ends_at,
           meeting_link   = coalesce(p_meeting_link, meeting_link)
    where  appointment_id = p_appointment_id;

    if not found
        then raise exception 'appointment not found';
    end if;

end;
$$ language plpgsql;