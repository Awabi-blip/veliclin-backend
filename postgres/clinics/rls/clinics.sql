alter table clinics enable row level security;


create policy owners_and_staffs_view_clinics on clinics;
for select 
using (
    owner_id = nullif(current_setting('myapp.user_id', true),
    '')::uuid
    
    or exists (
        select 1 from staffs_in_clinics as sic where 
        sic.staff_id = nullif(
            current_setting('myapp.user_id', true), '')::uuid
        and sic.clinic_id = clinics.clinic_id
    )
)

