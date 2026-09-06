-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database

select * from profiles;
select * from app_users;

select * from staffs_in_clinics where staff_id = '019f8caa-a51a-7e7f-8208-403bc23616b8'::UUID;


alter table profiles add column onboarded boolean not null default false;
select * from profiles;
alter table app_users drop column onboarded;
update profiles set onboarded = true
select * from profiles;


select * from profiles;
SELECT u.id, u.name, u.email, u.clerk_sub, p.id, p.DoB AS profile_id
FROM app_users u
LEFT JOIN profiles p ON p.id = u.id
ORDER BY u.id;

alter table app_users rename column supabase_sub to clerk_sub;

CREATE OR REPLACE FUNCTION register_users(
    f_sub TEXT,
    f_name TEXT,
    f_email TEXT
) RETURNS jsonb AS $$ 
DECLARE
v_user_id UUID;
v_response JSONB;
BEGIN  

    INSERT INTO app_users(name, email, clerk_sub)
    VALUES (f_name, f_email, f_sub)
    ON CONFLICT(clerk_sub)
    DO UPDATE
        SET name  = EXCLUDED.name,
            email = EXCLUDED.email
    RETURNING id into v_user_id;
    
    SELECT determine_auth_response(v_user_id)
    INTO v_response;
    
    return v_response;



END;
$$ LANGUAGE plpgsql;

select * from profiles;
select * from determine_auth_response('01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID)

CREATE OR REPLACE FUNCTION determine_auth_response(
    f_user_id UUID
) returns JSONB AS $$
DECLARE
v_staff_role e_staff_role;
v_onboarded BOOL;
v_expires_at TIMESTAMPTZ; 
v_clinic_id UUID;
response jsonb;
BEGIN

    --On normal insert, it would not, return something,
    --only on conflict it would return something, so its better to select it anyways.

    --check if they have a profile or not
    SELECT onboarded INTO v_onboarded FROM profiles WHERE
    id = f_user_id;

    --if no profile, the cookie is ProfileBuild
    IF NOT FOUND THEN
        response := jsonb_build_object('id', f_user_id, 'cookie', 'ProfileBuild');
    
    ELSE    
        -- given they have a profile
        -- now there are only 2 outcomes
        -- either they are in a clinic or not. (with owner or not)

        -- check if they are in a clinic:
        SELECT staff_role INTO v_staff_role 
        FROM staffs_in_clinics 
        WHERE staff_id = f_user_id;

        IF FOUND THEN
            -- check if they are owner and staff
            SELECT clinic_id, expires_at 
            INTO v_clinic_id, v_expires_at  
            FROM clinics  
            WHERE owner_id = f_user_id;
            
            -- if owner + staff then 
            IF FOUND THEN 
                response := jsonb_build_object('id', f_user_id, 'staff_role', v_staff_role, 'clinic_id', v_clinic_id,
                'cookie', 'Session', 'owner', true, 'expires_at', v_expires_at);
            --if only a staff member
            ELSE 
            
                SELECT clinic_id
                INTO v_clinic_id 
                FROM staffs_in_clinics 
                WHERE staff_id = v_user_id;
                
                SELECT expires_at 
                INTO v_expires_at
                FROM clinics
                WHERE clinic_id;

                response := jsonb_build_object('id', f_user_id, 'staff_role', v_staff_role,'clinic_id', v_clinic_id,
                'cookie', 'Session', 'owner', false, 'expires_at', v_expires_at );
            END IF;
        ELSE 
            -- check if only owner
            SELECT clinic_id, expires_at 
            INTO v_clinic_id, v_expires_at
            FROM clinics
            WHERE owner_id = f_user_id;
            
            IF FOUND THEN
                response := jsonb_build_object('id', f_user_id, 'staff_role', 'Owner'::e_staff_role,'clinic_id', v_clinic_id,
                'cookie', 'Session', 'owner', true, 'expires_at', v_expires_at);
            -- if not found in a clinic as staff or as a clinic owner
            -- then AND have profile
            -- then just check if their profile is onboarded
            ELSE
                response := jsonb_build_object('id', f_user_id, 'onboarded', v_onboarded, 'cookie', 'Invitation');
            END IF;
        END IF;
    END IF;

    RETURN response;

END;
$$ LANGUAGE plpgsql;





SELECT * FROM register_users('112168772870266188431', 'Keka kik', 'kekakik973@gmail.com', 'okay');

SELECT id, onboarded FROM app_users
WHERE google_id = '112168772870266188431';