-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database

CREATE OR REPLACE PROCEDURE reject_invitations(f_invitation_id INT)
SECURITY DEFINER
AS $$
DECLARE
    rejecter_id UUID := current_setting('myapp.user_id')::UUID;
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

    if not exists (
        select 1 from invitations 
        where invitation_id = f_invitation_id
        and   receiver_id   = rejecter_id
    ) then raise exception 'the inv id does not belong to you';
    end if;
    
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