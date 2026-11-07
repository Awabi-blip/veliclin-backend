-- Active: 1786733926332@@127.0.0.1@5433@veliclin_database

select * from doctors_schedule;

alter table doctors_schedule enable row level security;

create policy staffs_see_doctors_schedule
on doctors_schedule
for select
using (
    exists (select 1 from staffs_in_clinics
    where staffs_in_clinics.clinic_id = doctors_schedule.clinic_id)
);

create policy staffs_update_doctors_schedule
on doctors_schedule
for update
using (
    exists (select 1 from staffs_in_clinics
    where staffs_in_clinics.clinic_id = doctors_schedule.clinic_id)
);


create policy staffs_insert_doctors_schedule
on doctors_schedule
for insert
with check (
    exists (select 1 from staffs_in_clinics
    where staffs_in_clinics.clinic_id = doctors_schedule.clinic_id)
);
