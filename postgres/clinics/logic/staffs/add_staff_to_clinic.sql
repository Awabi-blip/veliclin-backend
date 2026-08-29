--create a function to add staff to clinic
--first check that the auth.uid person is the owner of the clinic
--then let them send inviations to people, upon invitation accept/reject invitation
--if its accepted, then insert them as a staff, based on their id


CALL send_invitations(
'ayesha@gmail.com',
'Doctor'::e_staff_role);

CREATE OR REPLACE PROCEDURE send_invitations(
    p_receiver_email CITEXT,
    p_role_invited_for e_staff_role
)
AS $$
DECLARE
    v_sender_id UUID := current_setting('myapp.user_id')::UUID;
    v_sender_email CITEXT;
    v_clinic_id UUID;
    v_receiver_id UUID;
BEGIN

    if v_sender_id is NULL then
        raise exception 'not found';
    end if;

    --now fetch owner_id
    select email into v_sender_email
    from app_users
    where id = v_sender_id;

    if not found then
        raise exception 'not found'; 
    end if;

    select id into v_receiver_id
    from app_users
    where email = p_receiver_email;

    if not found then
        raise exception 'not found';
    end if;

    select clinic_id into v_clinic_id
    from staffs_in_clinics
    where staff_id = v_sender_id
    and   staff_role = 'Manager'::e_staff_role;

    if not found then
        select clinic_id into v_clinic_id
        from clinics
        where owner_id = v_sender_id;

        if not found then 
            raise exception 'not found';
        end if;

    end if;
    

    insert into invitations(
        sender_id,
        clinic_id,
        role_invited_for,
        sender_email,
        receiver_email,
        receiver_id)
    values ( 
        v_sender_id,
        v_clinic_id,
        p_role_invited_for,
        v_sender_email,
        p_receiver_email,
        v_receiver_id
        );
    
END;
$$ language plpgsql;



-- select clinic_id into v_clinic_id
-- from staffs_in_clinics
-- where staff_id = v_sender_id;
CREATE INDEX idx_send_invitations ON staffs_in_clinics (
    staff_id
) INCLUDE (clinic_id);



CALL accept_invitations(3);

CREATE OR REPLACE PROCEDURE accept_invitations(f_invitation_id INT)
AS $$
DECLARE
    v_accepter_id UUID := current_setting('myapp.user_id')::UUID;
    v_clinic_id UUID;
    v_role_invited_for E_staff_role;
    v_accepter_email CITEXT := (SELECT email FROM app_users WHERE id = v_accepter_id);

BEGIN
    -- better to be explicit, even tho it would be fine if i missed this
    -- the schema enforces not null, so querying by null later would result in not found anyway
    -- better to prevent querying from happening

    if (v_accepter_id is null) or (v_accepter_email is null)
        then raise exception 'Unauthorised';
    end if;
    
    SELECT clinic_id, role_invited_for
    INTO v_clinic_id, v_role_invited_for
    FROM invitations 
        WHERE invitation_id   = f_invitation_id
        AND   receiver_email  = v_accepter_email
        AND   receiver_id     = v_accepter_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'not found';
    END IF;

    INSERT INTO staffs_in_clinics(
        staff_id,
        clinic_id,
        staff_role,
        is_active
    ) VALUES (
        v_accepter_id,
        v_clinic_id,
        v_role_invited_for,
        TRUE
    );
    
    -- again better to be explicit
    -- if the above condition is evaluated
    -- the not found is not run
    -- that means that the primary key invitation_id is associated to
    -- that record where accepter_email and accepter_id match
    -- i can delete by simply the id, but again, better to be explicit.
    
    DELETE FROM invitations 
    WHERE invitation_id = f_invitation_id
    AND receiver_email  = v_accepter_email
    AND receiver_id     = v_accepter_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE reject_invitations(f_invitation_id INT)
AS $$
DECLARE
    v_accepter_id UUID := current_setting('myapp.user_id')::UUID;
    v_clinic_id UUID;
    v_role_invited_for E_staff_role;
    v_accepter_email CITEXT := (SELECT email FROM app_users WHERE id = v_accepter_id);
BEGIN
    
    -- better to be explicit, even tho it would be fine if i missed this
    -- the schema enforces not null, so querying by null later would result in not found anyway
    -- better to prevent querying from happening
    
    if (v_accepter_id is null) or (v_accepter_email is null)
        then raise exception 'Unauthorised';
    end if;

    SELECT clinic_id, role_invited_for
    INTO v_clinic_id, v_role_invited_for
    FROM invitations 
        WHERE invitation_id = f_invitation_id
        AND receiver_email  = v_accepter_email
        AND receiver_id     = v_accepter_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'not found';
    END IF;
    
    -- again better to be explicit
    -- if the above condition is evaluated
    -- the not found is not run
    -- that means that the primary key invitation_id is associated to
    -- that record where accepter_email and accepter_id match
    -- i can delete by simply the id, but again, better to be explicit.

    DELETE FROM invitations 
    WHERE invitation_id = f_invitation_id
    AND receiver_email  = v_accepter_email
    AND receiver_id     = v_accepter_id;

END;
$$ LANGUAGE plpgsql;