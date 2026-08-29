CREATE OR REPLACE FUNCTION create_profile(
f_user_id UUID,
f_first_name VARCHAR(50), 
f_last_name VARCHAR(50), 
f_gender e_gender, 
f_DoB DATE )
RETURNS JSONB AS $$
DECLARE
v_response JSONB;
BEGIN

    INSERT INTO profiles 
    (id, first_name, last_name, gender, DoB) VALUES 
    (f_user_id, f_first_name, f_last_name, f_gender, f_DoB);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Could not add user';
    END IF;

    SELECT determine_auth_response(f_user_id)
    INTO v_response;
    
    return v_response;


END;
$$ LANGUAGE plpgsql;