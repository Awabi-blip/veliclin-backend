-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
--create a function to create a new clinic
--in that function, make a new clinic, and make the owner the auth.uid() guy


select * from app_users;

set myapp.user_id = '01a1901c-54a3-7224-b1b2-204d651d3f3a';

SELECT current_setting('myapp.user_id');
BEGIN;
SELECT create_new_clinic(
    'Downtown Health Clinic',          -- p_clinic_name (VARCHAR)
    'Aesthetic_Clinic'::e_clinic_type,          -- p_clinic_type (ENUM e_clinic_type)
    'New York',                        -- p_city (VARCHAR)
    '123 Medical Way, Suite 400',       -- p_address (VARCHAR)
    '+15551234567',                    -- p_contact_number (VARCHAR)
    'https://example.com/banner.jpg',  -- p_banner_url (TEXT)
    FALSE,                              -- p_all_visibility (BOOLEAN)
    'America/New_York',                -- p_timezone (VARCHAR)
    'Doctor'::e_staff_role              -- p_self_role (ENUM e_staff_role, optional)
);

-- Aborts any query taking longer than 5 seconds for this user
ALTER ROLE app SET statement_timeout = '5s';
ROLLBACK;
COMMIT;

set role postgres;

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

    if v_owner_id is null then
        raise exception using
        errcode = 'P2001',
        message = 'please sign in and try again!';
    end if;

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


