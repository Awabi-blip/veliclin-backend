-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
--refactor this to have schedule id
--that schedule id, will be linked to appointments
--upon deletion of schedule, it will be a soft delete
--and in the procedure, of deleting schedule, you would just
--soft delete it, and set the related appointments to cancelled

select * from staffs_in_clinics;

select * from doctors_schedule;
SET myapp.user_id = '019f8cbb-caf8-7fb4-99e4-88421e1167c2';

select * from doctors_schedule;
set role postgres;
select * from clinics;

CALL add_appointments(
    '019f8cbb-caf8-7fb4-99e4-88421e1167c2',   -- doctor_id
    '019fa632-8b75-7d11-bd7b-08433bf0f0d7',   -- patient_id
    '2026-07-27 13:00:00+05',                 -- 08:00 UTC, duration_hours
    1.0,                                      -- duration_hours (1 hour)
    'https://meet.example.com/abc'            -- meeting_link
);

create or replace procedure add_appointments(
    p_doctor_id      uuid,
    p_patient_id     uuid,
    p_scheduled_at   timestamptz,
    p_duration_hours decimal(2, 1),
    p_meeting_link   VARCHAR(2048)
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
        and    is_active  = true

    );
    v_valid_doctor_clinic_id  uuid           := (
        select clinic_id
        from   staffs_in_clinics
        where  staff_id = p_doctor_id
        and    is_active  = true

    );

    v_ends_at                timestamptz     := p_scheduled_at + (p_duration_hours * interval '1 hour');
    
    v_appointment_start_day  e_working_days  := (
        select day
        from   lookup_days
        where  id = extract(isodow from p_scheduled_at)
    );

    v_timezone                varchar(64)     := (select timezone from clinics where clinic_id = v_valid_doctor_clinic_id);
    
    v_appointment_start_time  time            := (p_scheduled_at at time zone  v_timezone)::time;
    v_appointment_end_time    time            := (p_scheduled_at at time zone  v_timezone + (p_duration_hours * interval '1 hour'))::time;
    v_schedule_id             int;
begin

    if v_valid_clinic_id    is null or v_valid_doctor_clinic_id is null or 
    v_timezone                is null or v_appointment_start_time is null or 
    v_appointment_end_time  is null
    then
        raise exception using 
        errcode = 'P2001',
        message = 'unauthorised';
    end if;

    if v_valid_doctor_clinic_id != v_valid_clinic_id then
        raise exception using 
        errcode = 'P2001', 
        message = 'clinic ids dont match'; -- BUG: missing semicolon in original
    end if;

    if p_duration_hours not in (0.5, 1, 1.5, 2) then
        raise exception using 
        errcode = 'P2001',
        message = 'invalid duration: must be 0.5, 1, 1.5, or 2 hours';
    end if;

    -- perform pg_advisory_xact_lock(
    --     hashtext(p_doctor_id::text),
    --     hashtext(p_patient_id::text)
    -- ); -- the unique index would catch it

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


    if not found then
        raise exception using 
        errcode = 'P2001',
        message = 'appointment falls outside the doctor''s available schedule';
    end if;

    insert into appointments (
        doctor_id,
        doctor_role,
        doctor_schedule_id,
        patient_id,
        clinic_id,
        scheduled_at,
        ends_at,
        meeting_link
    ) values (
        p_doctor_id,
        'Doctor'::e_staff_role,
        v_schedule_id,
        p_patient_id,
        v_valid_doctor_clinic_id,
        p_scheduled_at,
        v_ends_at,
        p_meeting_link
    );

end;
$$ language plpgsql;