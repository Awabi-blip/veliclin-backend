create or replace procedure add_data_to_appointment(
    p_appointment_id bigint,
    p_note           varchar(1000),
    p_diagnosis      varchar(500),
    p_fee            decimal(12, 2)
)
security definer
language plpgsql
as $$
declare
    v_doctor_id        uuid := current_setting('myapp.user_id')::uuid;
    
    v_valid_clinic_id  uuid := (
        select clinic_id
        from   staffs_in_clinics
        where  staff_id   = v_doctor_id
          and  staff_role = 'Doctor'::e_staff_role
          and  is_active  = true
    );
    
    v_valid_patient_id      UUID;
    v_appointment_status    e_appointment_status;
begin
    if v_valid_clinic_id is null then
        raise exception 'unauthorised';
    end if;

    select patient_id, status 
    into   v_valid_patient_id, v_appointment_status
        from   appointments
        where  appointment_id = p_appointment_id
          and  doctor_id      = v_doctor_id
          and  status in ('On_going'::e_appointment_status, 'Completed'::e_appointment_status);

    if v_valid_patient_id is null then
     raise exception 'appointment not found, not yours, or has not been started';
    end if;

    if not exists (
        select 1
        from   patients_in_clinics
        where  patient_id = v_valid_patient_id
          and  clinic_id  = v_valid_clinic_id
          and  added_by   = v_doctor_id
    ) then
        raise exception 'patient not found';
    end if;

    insert into appointments_information 
    (appointment_id, note, diagnosis, fee, status)
    values 
    (p_appointment_id, p_note, p_diagnosis, p_fee, 
    v_appointment_status)
    on conflict (appointment_id) 
    do update set
        note      = EXCLUDED.note,
        diagnosis = EXCLUDED.diagnosis,
        fee       = EXCLUDED.fee,
        status    = v_appointment_status;

    if not found
        then raise exception 'could not update';
    end if;

end;
$$;

