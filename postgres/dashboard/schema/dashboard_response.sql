select * from profiles;

create or replace function return_dashboard_response (
) 
returns jsonb 
security definer 
as $$
declare
    v_staff_id                     uuid := current_setting('myapp.user_id')::UUID;

    v_clinic_id                    uuid := (select clinic from staffs_in_clinics
                                        where staff_id = v_staff_id);

    v_upcoming_appointments_rec    jsonb;
    v_upcoming_appointments_count  integer;
   
    v_patients_rec                 jsonb;
    v_patients_count               integer;

    v_staff_rec                    jsonb;
    v_staff_count                  integer;
    
    v_response                     jsonb;
    
begin

    if v_staff_id is null or v_clinic_id is null
        then raise exception 'Unauthorised';
    end if;

    select   coalesce (jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into     v_upcoming_appointments_rec
    from (
        select   concat(pic.first_name, ' ', pic.last_name) AS patient_name
        from     patients_in_clinics as pic
        join     appointments        as app
        on       app.patient_id      =  pic.patient_id
        where    app.status          =  upcoming
        and      app.clinic_id       =  v_clinic_id
        order by scheduled_at        asc
        limit 5
    )   as x;

    select    count(1)
    into      v_upcoming_appointments_count
    from      appointments
    where     clinic_id           = v_clinic_id;

    select   coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into     v_patients_rec
    from  (
        select   concat(pic.first_name, ' ', pic.last_name) as patient_name
        from     patients_in_clinics as pic
        where    pic.clinic_id       =  v_clinic_id
        order by pic.added_at        desc
        limit 5
    ) as x;

    select    count(1)
    into      v_patients_count
    from      patients_in_clinics
    where     clinic_id           = v_clinic_id;

    select   coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into     v_staff_rec
    from  (
        select   concat(prf.first_name, ' ', prf.last_name) as staff_name,
                 sic.role                                   as staff_role
        from     staffs_in_clinics as sic
        join     profiles          as prf
        on       sic.staff_id       =  prf.id
        where    sic.is_active      =  true
        and      sic.clinic_id      =  v_clinic_id
    ) as x;

    select count(1)
    into   v_staff_count
    from   staffs_in_clinics
    where  clinic_id = v_clinic_id;

    v_response  := jsonb_build_object (
        'v_appointments_count', v_upcoming_appointments_count,
        'appointments_rec', v_upcoming_appointments_rec,

        'patients_count', v_patients_count,
        'patients_rec', v_patients_rec,

        'staffs_count', v_staff_count,
        'staff_rec',    v_staff_rec
    );

    return v_response;

end;
$$ language plpgsql;


select * from patients_in_clinics;

alter table patients_in_clinics add column added_at timestamptz not null default now();