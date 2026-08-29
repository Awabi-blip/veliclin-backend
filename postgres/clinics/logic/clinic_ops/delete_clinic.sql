create or replace procedure delete_clinics(
)
as $$
declare
    v_user_id   uuid   := current_setting('myapp.user_id')::UUID;
    v_clinic_id uuid   := (select clinic_id from clinics where owner_id
                     = v_user_id);
begin
    
    if v_user_id is null or v_clinic_id is null
        then raise exception 'unauthorized to commit this action';
    end if;

    delete from clinics
    where 
        clinic_id = v_clinic_id;
    
end;
$$ language plpgsql;
