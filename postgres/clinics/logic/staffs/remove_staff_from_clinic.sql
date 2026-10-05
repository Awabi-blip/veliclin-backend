create or replace procedure remove_staff_from_clinics(v_victim_id UUID)
security definer as $$
declare
    v_user uuid := current_setting('myapp.user_id')::uuid;
    v_victim_role e_staff_role  := (select staff_role from staffs_in_clinics where id = v_victim_id);
begin

    if v_user is null then
    raise exception using
        errcode = 'P2001',
        message = 'you are unauthorised to do this action';  
    end if;

    if v_victim_role is null then
        raise exception using
        errcode = 'P2001',
        message = 'staff to be removed does not exist';  
    end if;

    perform 1 from 
    clinics
    where owner_id = v_user;

    if not found then
        if v_victim_role = 'Manager'::e_staff_role then
        
        raise exception using
            errcode = 'P2001',
            message = 'non owners can not remove manager';  
        end if;
 
        perform 1 from
        staffs_in_clinics
        where staff_role = 'Manager'::e_staff_role
        and   staff_id   =  v_user;
        
        if not found then 
        raise exception using
            errcode = 'P2001',
            message = 'you are not allowed to remove anyone';  
        end if;
    
    end if;

    update staffs_in_clinics
    set    is_active = false
    where  staff_id  = v_victim_id;
end;
$$ language plpgsql;


SELECT enumlabel
FROM pg_enum
WHERE enumtypid = 'e_appointment_status'::regtype
ORDER BY enumsortorder;

select * from invitations;