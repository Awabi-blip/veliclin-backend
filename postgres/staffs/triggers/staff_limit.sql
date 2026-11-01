create or replace function check_staff_limit()
returns trigger as $$
declare
    v_total_staff smallint;
    staff_limit SMALLINT;
    doctor_limit SMALLINT;
    v_plan e_clinic_plan;
begin

    select 
        plan into v_plan
    from 
        clinics
    where
        clinic_id = new.clinic_id;

    if v_plan = 'basic'::e_clinic_plan then
    	staff_limit := 6;
    	doctor_limit := 3;
   elseif v_plan = 'premium'::e_clinic_plan then
   	    staff_limit := 8;
   	    doctor_limit := 6;
   end if;

    if new.staff_role = 'Doctor'::e_staff_role then
        
        select count(1) into v_total_staff 
        from staffs_in_clinics 
        where staff_role = 'Doctor'::E_staff_role
        and clinic_id = new.clinic_id;

        if v_total_staff = staff_limit then
            raise exception 'Your current plan does not allow more than 3 Doctors';
        end if;
    
    else 

        select count(1) into v_total_staff 
        from staffs_in_clinics 
        where staff_role != 'Doctor'::E_staff_role
        and clinic_id = new.clinic_id;

        if v_total_staff = doctor_limit then
            raise exception 'Your current plan does not allow more than 6 staff members';
        end if;
    
    end if;

    return new;

end;
$$ language plpgsql;

create or replace trigger enforce_staff_limits
before insert on staffs_in_clinics
for each row
execute function check_staff_limit();