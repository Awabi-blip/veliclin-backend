## Done:

- update appointments (doctors only)
- add appointments (staff + doctors) **( one function )**
- view appointments (staff + doctors) **( 2 separate function)**
- Delete appointments doctors
- Delete appoinments staffs

## Remaining:
- add a price thing for appointments
- add, delete, view, update prescriptions

## Todo Next:
- Make a return_type for owner_role.
- Write RLS for owner.


## Security Model:
- Except for stored procedures, inserts, updates, deletes should be implemented in RLS.
- For selects, it should be all in RLS.
- For direct updates/deletes/inserts it should be in RLS.