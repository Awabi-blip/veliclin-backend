create or replace procedure add_patients_data (
    p_patient_id  uuid,
    p_neurotype   e_neurotype,
    p_blood_type  e_blood_type,
    p_height_cm   decimal(4,1),
    p_weight_kg   decimal(5,2),
    p_note        varchar(500)
) as $$
declare
    v_valid_clinic_id uuid;
    v_added_by_id     uuid;
begin
    
    select clinic_id, added_by
    into   v_valid_clinic_id, v_added_by_id
    from   patients_in_clinics
    where  patient_id = p_patient_id;

    if not found
        then raise exception 'the patient does not exist';
    end if;

    insert into patients_information(
        patient_id, added_by, clinic_id, neurotype,bloodtype,
        height_cm, weight_kg, note
    ) values (
        p_patient_id, v_added_by_id, v_valid_clinic_id,
        p_neurotype, p_blood_type, p_height_cm, p_weight_kg,
        p_note)
    on conflict (patient_id)
    do update set 
        neurotype  = excluded.neurotype,
        blood_type = excluded.blood_type,
        height_cm  = excluded.height_cm,
        weight_kg  = excluded.weight_kg,
        note       = excluded.note
    ;


end
$$ language plpgsql;
    



