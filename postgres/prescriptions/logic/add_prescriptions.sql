create or replace procedure add_prescriptions(
    p_appointment_id    bigint,
    p_patient_id        uuid,
    p_medication        text,
    p_potency           text,
    p_frequency         text,
    p_end_date          date,
    p_start_date        date default current_date,
    p_metadata          jsonb default null
)
as $$
declare 
    v_doctor_id   uuid      :=  current_setting('myapp.user_id');
    v_clinic_id   uuid      :=  (select clinic_id FROM staffs_in_clinics where staff_id = v_doctor_id
                                and staff_role = 'Doctor'::e_staff_role);

begin
    if v_clinic_id is null then raise exception 'unauthorised';
    end if;

    if not exists (
        select 1 from patients_in_clinics where patient_id = p_patient_id
        and clinic_id = v_clinic_id
        and added_by = v_doctor_id
    ) then raise exception 'patient not found, or not yours';
    end if;

    insert into patient_prescriptions (
        appointment_id,
        patient_id,
        patient_clinic_id,
        doctor_id,
        doctor_role,
        doctor_clinic_id,
        medication,
        potency,
        frequency,
        start_date,
        end_date,
        metadata
    ) values (
        p_appointment_id,
        p_patient_id,
        v_clinic_id,
        v_doctor_id,
        'Doctor'::e_staff_role,
        v_clinic_id,
        p_medication,
        p_potency,
        p_frequency,
        p_start_date,
        p_end_date,
        p_metadata
    );


end;
$$ language plpgsql;