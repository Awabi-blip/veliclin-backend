CREATE OR REPLACE PROCEDURE accept_invitations(f_invitation_id INT)
SECURITY DEFINER
AS $$
DECLARE
    v_accepter_id UUID := nullif(current_setting('myapp.user_id', true), '')::UUID;
    v_clinic_id UUID   := (select clinic_id from invitations where invitation_id = f_invitation_id);
    v_role_invited_for e_staff_role := (select role_invited_for from invitations where invitation_id = f_invitation_id);
    v_accepter_email CITEXT := (SELECT email FROM app_users WHERE id = v_accepter_id);

BEGIN
    -- better to be explicit, even tho it would be fine if i missed this
    -- the schema enforces not null, so querying by null later would result in not found anyway
    -- better to prevent querying from happening
    if (v_accepter_id is null) or (v_accepter_email is null) or (v_clinic_id is null)
        then raise exception using
        errcode = 'P2001',
        message = 'Unauthorised';
    end if;

    if not exists (
        select 1 from invitations 
        where invitation_id = f_invitation_id
        and   receiver_id   = v_accepter_id
    ) then raise exception using
        errcode = 'P2001',
        message = 'the inv id does not belong to you';
    end if;
    
    begin
        insert into staffs_in_clinics(
            staff_id,
            clinic_id,
            staff_role,
            is_active
        ) values (
            v_accepter_id,
            v_clinic_id,
            v_role_invited_for,
            true
        );
    exception when unique_violation then
        raise exception using
        errcode = 'P2001',
        message = 'leave your current clinic before accepting another invitation';
    end;

    
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

create or replace function tests_accept_invitations_should_pass()
returns setof text as $$
declare
    v_invitation_id INT;
begin
    
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);
    
    CALL send_invitations(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Doctor'::e_staff_role);

    select invitation_id into v_invitation_id
    from   invitations 
    where  sender_id   = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID
    and    receiver_id = '01a08493-22e5-7800-b28b-49fd98035d05'::UUID
    and    clinic_id   = '01a06173-6dbf-7314-937e-1386bc4fe707'::UUID
    and    role_invited_for = 'Doctor'::e_staff_role;
            
    perform set_config('myapp.user_id', '01a08493-22e5-7800-b28b-49fd98035d05', true);

    return next lives_ok(        
        format($q$ CALL accept_invitations(%s) $q$, v_invitation_id),
        'accept_invitations should execute successfully'
    );

end;
$$ language plpgsql;


-- null user: nobody logged in
create or replace function test_accept_invitations_fails_when_unauthenticated()
returns setof text as $$
declare
    v_invitation_id INT;
begin
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);

    CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role);

    select invitation_id into v_invitation_id
    from   invitations
    where  sender_id        = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID
    and    receiver_id      = '01a08493-22e5-7800-b28b-49fd98035d05'::UUID
    and    clinic_id        = '01a06173-6dbf-7314-937e-1386bc4fe707'::UUID
    and    role_invited_for = 'Doctor'::e_staff_role;

    perform set_config('myapp.user_id', '', true);

    return next throws_ok(
        format($q$ CALL accept_invitations(%s) $q$, v_invitation_id),
        'P2001',
        'Unauthorised',
        'no user id is rejected'
    );
end;
$$ language plpgsql;


create or replace function test_accept_invitations_fails_when_invitation_not_yours()
returns setof text as $$
declare
    v_invitation_id INT;
begin
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);

    CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role);

    select invitation_id into v_invitation_id
    from   invitations
    where  sender_id        = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID
    and    receiver_id      = '01a08493-22e5-7800-b28b-49fd98035d05'::UUID
    and    clinic_id        = '01a06173-6dbf-7314-937e-1386bc4fe707'::UUID
    and    role_invited_for = 'Doctor'::e_staff_role;

    perform set_config('myapp.user_id', '01a0d811-cd16-7437-b1da-8966faec33c4', true);

    return next throws_ok(
        format($q$ CALL accept_invitations(%s) $q$, v_invitation_id),
        'P2001',
        'the inv id does not belong to you',
        'another user cannot accept this invitation'
    );
end;
$$ language plpgsql;


create or replace function test_accept_invitations_fails_when_already_staff()
returns setof text as $$
declare
    v_invitation_id INT;
begin
    
    -- first invite + accept, so the receiver is now in staffs_in_clinics
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);
    CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role);

    select invitation_id into v_invitation_id
    from   invitations
    where  sender_id        = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID
    and    receiver_id      = '01a08493-22e5-7800-b28b-49fd98035d05'::UUID
    and    clinic_id        = '01a06173-6dbf-7314-937e-1386bc4fe707'::UUID
    and    role_invited_for = 'Doctor'::e_staff_role;

    perform set_config('myapp.user_id', '01a08493-22e5-7800-b28b-49fd98035d05', true);
    CALL accept_invitations(v_invitation_id);

    -- second invite to the same person (the first one was deleted on accept)
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);
    CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role);

    select invitation_id into v_invitation_id
    from   invitations
    where  sender_id        = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'::UUID
    and    receiver_id      = '01a08493-22e5-7800-b28b-49fd98035d05'::UUID
    and    clinic_id        = '01a06173-6dbf-7314-937e-1386bc4fe707'::UUID
    and    role_invited_for = 'Doctor'::e_staff_role;

    -- accepting again hits the unique constraint
    perform set_config('myapp.user_id', '01a08493-22e5-7800-b28b-49fd98035d05', true);

    return next throws_ok(
        format($q$ CALL accept_invitations(%s) $q$, v_invitation_id),
        'P2001',
        'leave your current clinic before accepting another invitation',
        'cannot accept an invitation when already staff'
    );
end;
$$ language plpgsql;


delete from clinics where owner_id = '01a0d811-cd16-7437-b1da-8966faec33c4';

--taha test account with clinic    = 01a03e8a-e7fc-7a52-b510-a7dc3b784923 
--taha test account without clinic = '01a08493-22e5-7800-b28b-49fd98035d05 (tahaadnanawan)'

select * from clinics where owner_id = '01a03e8a-e7fc-7a52-b510-a7dc3b784923';
