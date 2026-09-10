-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database
select * from profiles;


select * from staffs_in_clinics where staff_id = '01a08493-22e5-7800-b28b-49fd98035d05'

SET myapp.user_id = '01a03e8a-e7fc-7a52-b510-a7dc3b784923'

select * from return_dashboard_response(
);

create or replace function return_dashboard_response (
) 
returns jsonb 
security definer 
as $$
declare
    v_staff_id                     uuid := current_setting('myapp.user_id')::UUID;

    v_clinic_id                    uuid;

    v_upcoming_appointments_rec    jsonb;
    v_upcoming_appointments_count  integer;
   
    v_patients_rec                 jsonb;
    v_patients_count               integer;

    v_staff_rec                    jsonb;
    v_staff_count                  integer;
    
    v_response                     jsonb;
    
begin

    if v_staff_id is null
        then raise exception 'Unauthorised';
    end if;

    select clinic_id into v_clinic_id
    from  staffs_in_clinics 
    where staff_id  = v_staff_id
    and   is_active = true;

    if v_clinic_id is null then
        select clinic_id into v_clinic_id from clinics
        where owner_id = v_staff_id;
    end if;

    if v_clinic_id is null then 
        raise exception using 
        errcode = 'P2001',
        message = 'unauthorized';
    end if;

    
    select   coalesce (jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into     v_upcoming_appointments_rec
    from (
        select   concat(pic.first_name, ' ', pic.last_name) AS patient_name
        from     patients_in_clinics as pic
        join     appointments        as app
        on       app.patient_id      =  pic.patient_id
        where    app.status          =  'Scheduled'::e_appointment_status
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
                 sic.staff_role                             as staff_role
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