
set role postgres;

CREATE OR REPLACE PROCEDURE add_patients_to_clinics(    
    p_doctor_id     UUID ,
    p_first_name    VARCHAR(40),
    p_last_name     VARCHAR(40),
    p_phone_number  VARCHAR(15),
    p_gender        E_gender,
    p_email         CITEXT DEFAULT NULL

    )
AS $$
DECLARE
    v_staff_id                    uuid :=  current_setting('myapp.user_id');
    
    v_valid_clinic_id             uuid := (
            select clinic_id
            from   staffs_in_clinics
            where  staff_id   = v_staff_id
            and  staff_role in (
                'Doctor'::e_staff_role,
                'Manager'::e_staff_role,
                'Receptionist'::e_staff_role
            )
        );

        v_valid_doctor_clinic_id    uuid := (
            select clinic_id
            from   staffs_in_clinics
            where  staff_id = p_doctor_id
        );
BEGIN

    -- need to validate that doctor belongs to the same clinic as staff.
    if v_valid_clinic_id is null or v_valid_doctor_clinic_id is null 
    then raise exception 'unauthorised';
    end if;

    if v_valid_clinic_id != v_valid_doctor_clinic_id then raise exception 'bad request';
    end if;
    
    INSERT INTO patients_in_clinics (
        added_by,
        adder_role,
        clinic_id,
        first_name,
        last_name,
        contact_number,
        email,
        gender
        ) VALUES (
        p_doctor_id,
        'Doctor'::e_staff_role,
        v_valid_clinic_id,
        p_first_name,
        p_last_name,
        p_phone_number,
        p_email,
        p_gender
        );

END;
$$ LANGUAGE plpgsql;