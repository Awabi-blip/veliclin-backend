-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
--create a function to create a new clinic
--in that function, make a new clinic, and make the owner the auth.uid() guy
CALL create_new_clinic(
    'Devil Trigger',
    'Aesthetic_Clinic'::e_clinic_type,
    'Temen-ni-gru',
    'Highest Chamber, Demon World',
    '330109121',
    NULL,
    NULL
);

SELECT current_setting('myapp.user_id');
DROP PROCEDURE create_new_clinic;

CREATE OR REPLACE FUNCTION create_new_clinic(
    p_clinic_name VARCHAR(100),
    p_clinic_type e_clinic_type,
    p_city VARCHAR(100),
    p_address VARCHAR(500),
    p_contact_number VARCHAR(15),
    p_banner_url TEXT,
    p_all_visibility BOOLEAN,
    p_timezone VARCHAR(64),
    p_self_role e_staff_role DEFAULT NULL
    
) RETURNS JSONB AS $$
DECLARE
    v_owner_id UUID := current_setting('myapp.user_id');
    v_clinic_id UUID;
    v_expires_at DATE;
    v_response JSONB;
BEGIN

    IF v_owner_id IS NULL 
        THEN RAISE EXCEPTION 'Action can not be commited, Please try again later.';
    END IF;

    v_expires_at := (CURRENT_DATE + INTERVAL '14 days');

    INSERT INTO clinics (
        owner_id,
        clinic_name,
        clinic_type,
        city_name,
        address,
        contact_number,
        banner_url,
        all_visibility,
        expires_at,
        timezone
    ) VALUES (
        v_owner_id,
        p_clinic_name,
        p_clinic_type,
        p_city,
        p_address,
        p_contact_number,
        p_banner_url,
        p_all_visibility,
        v_expires_at,
        p_timezone
    ) RETURNING clinic_id into v_clinic_id;

    IF p_self_role IS NOT NULL THEN
        INSERT INTO staffs_in_clinics (
            clinic_id, staff_id, staff_role
        ) VALUES (v_clinic_id, v_owner_id, p_self_role);
    END IF;

    SELECT determine_auth_response(v_owner_id) 
    INTO v_response;

    return v_response;


END;
$$ LANGUAGE plpgsql;


