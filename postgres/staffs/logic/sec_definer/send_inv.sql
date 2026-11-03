-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database


CREATE OR REPLACE PROCEDURE send_invitations(
    p_receiver_email CITEXT,
    p_role_invited_for e_staff_role
)
SECURITY DEFINER
AS $$
DECLARE
    v_sender_id UUID := nullif(current_setting('myapp.user_id', true), '')::UUID;
    v_sender_email CITEXT;
    v_clinic_id UUID;
    v_receiver_id UUID;
BEGIN

    if v_sender_id is NULL then
    raise exception using
        errcode = 'P2001',
        message = 'you are unauthorised to do this action';
    end if;

    --now fetch owner_id
    select email into v_sender_email
    from app_users
    where id = v_sender_id;

    if not found then
    raise exception using
        errcode = 'P2001',
        message = 'you are unauthorised to do this action';       
    end if;

    select id into v_receiver_id
    from app_users
    where email = p_receiver_email;

    if v_receiver_id = v_sender_id then
    raise exception using
        errcode = 'P2001',
        message = 'you can not send your self an invite';
    end if;

    if not found then
        raise exception using
        errcode = 'P2001',
        message = 'the person you are trying to add to your clinic is not registered';  
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
        raise exception using
            errcode = 'P2001',
            message = 'you are unauthorised to do this action';  
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


CREATE EXTENSION pgtap;

#taha test account with clinic owner   = 01a03e8a-e7fc-7a52-b510-a7dc3b784923 (only owner)
#taha test account without clinic      = '01a08493-22e5-7800-b28b-49fd98035d05'
#awab test account with clinic owner + manager = awabhero34@gmail.com, 01a1901c-54a3-7224-b1b2-204d651d3f3a

create or replace function test_send_invitations_should_pass_because_owner_with_manager_role_sends_invite()
returns setof text as $$
begin                                   --'awabhero34@gmail.com owner+manager of Majima x Makoto'
    perform set_config('myapp.user_id', '01a1901c-54a3-7224-b1b2-204d651d3f3a', true);

    return next lives_ok(        
        $q$  CALL send_invitations(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Doctor'::e_staff_role)
        $q$,
        'Send invitations should execute successfully because owner+manager invites'
        );    
end;
$$ language plpgsql;


create or replace function test_send_invitations_should_pass_because_owner_with_doctorh_role_sends_invite()
returns setof text as $$
begin                                 --'awabzero34@gmail.com owner+doctor of Raiden'
    perform set_config('myapp.user_id', '019f8caa-a51a-7e7f-8208-403bc23616b8', true);

    return next lives_ok(        
        $q$  CALL send_invitations(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Doctor'::e_staff_role)
        $q$,
        'Send invitations should execute successfully because owner+manager invites'
        );    
end;
$$ language plpgsql;


create or replace function tests_send_invitations_should_pass_because_owner_sends_invite()
returns setof text as $$
begin
                                        --darkdaredevil575@gmail.com (owner only)
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);
    
    return next lives_ok(        
        $q$  CALL send_invitations(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Doctor'::e_staff_role)
        $q$,
        'Send invitations should execute successfully because owner only invites'
    );

end;
$$ language plpgsql;

create or replace function test_send_invitations_should_pass_because_manager_without_owner_sends_invite()
returns setof text as $$
begin                               
                                      -- kazmikhan676@gmail.com (manager of Test Clinic)
    perform set_config('myapp.user_id', '01a1a115-9b56-7f9b-a1cb-2a347933aa2f', true);

    return next lives_ok(        
        $q$  CALL send_invitations(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Doctor'::e_staff_role)
        $q$,
        'Send invitations should execute successfully because owner+manager invites'
        );    
end;
$$ language plpgsql;


--tahaadanawan@gmail.com is taha account which is not in clinic
create or replace function test_send_invitations_should_fail_because_doctor_sends_invite()
returns setof text as $$
begin
                                        --darkdaredevil20@gmail.com (doctor only)
    perform set_config('myapp.user_id', '01a07759-3b0e-7c2a-980d-fe8ee75586d3', true);

    return next throws_ok(
        $q$ CALL send_invitation(
            'tahaadnanawan@gmail.com'::CITEXT,
            'Manager'::e_staff_role)
        $q$,
            'P2001',
            'you are unauthorised to do this action'
            'fails because doctor user tried to invite someone'
    );

end;
$$ language plpgsql;

create or replace function test_send_invitations_fails_when_unauthenticated()
returns setof text as $$
begin

    perform set_config('myapp.user_id', '', true);

    return next throws_ok(
        $q$ CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role) $q$,
        'P2001',
        'you are unauthorised to do this action',
        'no user id is rejected'
    );
end;
$$ language plpgsql;


--fail because self invite
create or replace function test_send_invitations_should_fail_because_self_invite()
returns setof text as $$
begin
                                        --darkdaredevil575@gmail.com (owner only)
    perform set_config('myapp.user_id', '01a03e8a-e7fc-7a52-b510-a7dc3b784923', true);
    
    return next throws_ok(
        $q$ CALL send_invitations(
            'darkdaredevil575@gmail.com'::CITEXT,
            'Doctor'::e_staff_role)
        $q$,
            'P2001',
            'you can not send your self an invite'
    
    );

end;
$$ language plpgsql;


--should fail because no user_id
create or replace function test_send_invitations_fails_when_unauthenticated()
returns setof text as $$
begin

    perform set_config('myapp.user_id', '', true);

    return next throws_ok(
        $q$ CALL send_invitations('tahaadnanawan@gmail.com'::CITEXT, 'Doctor'::e_staff_role) $q$,
        'P2001',
        'you are unauthorised to do this action',
        'no user id is rejected'
    );
end;
$$ language plpgsql;


#taha test account with clinic owner   = 01a03e8a-e7fc-7a52-b510-a7dc3b784923 (only owner)
#taha test account without clinic      = '01a08493-22e5-7800-b28b-49fd98035d05'
#awab test account with clinic owner + manager = awabhero34@gmail.com, 01a1901c-54a3-7224-b1b2-204d651d3f3a


select * from clinics;
select * from app_users where id = '01a03e8a-e7fc-7a52-b510-a7dc3b784923';