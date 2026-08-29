create or replace procedure remove_staff_from_clinics(v_victim_id UUID)
security definer as $$
declare
    v_user uuid := current_setting('myapp.user_id')::uuid;
    v_victim_role e_staff_role  := (select staff_role from staffs_in_clinics where id = v_victim_id);
begin

    if v_user is null or v_victim_role is null then
        raise exception 'user or victim not found';
    end if;

    perform 1 from 
    clinics
    where owner_id = v_user;

    if not found then
        if v_victim_role = 'Manager'::e_staff_role then
             raise exception 'action can not be performed';
        end if;
 
        perform 1 from
        staffs_in_clinics
        where staff_role = 'Manager'::e_staff_role
        and   staff_id   =  v_user;
        
        if not found then 
            raise exception 'unauthorised';
        end if;
    
    end if;

    update staffs_in_clinics
    set    is_active = false
    where  staff_id  = v_victim_id;
end;
$$ language plpgsql;
