# An app for doctors for secure and buttery-smooth workflows

## Features/General Workflow:
An owner can create a clinic and add staff in there.
- Staff could have roles from ``` doctor, manager, receptionistu``` with each role having its own permissions/privileges

The owner can invite the staff via using their email that the staff used to create their veliclin account with.

--

## Features/Usage:
Create clinic

Add Staff

Add Patients     (only under a specific doctor_id)

Set Doctor Schedule

Add Appointments (any doctor with any registered patient)

Refer Patients

Track Prescriptions

--

## Feature usage with role permisions:
Create Appointment:
- Doctor, Manager, Receptionist

Add data to Appointment:
- Doctor (their own appointment only)

Cancel Appointment:
- Doctor, Manager, Receptionist

Reschedule Appointment:
- Doctor, Manager, Receptionist

Start Appointment:
- Doctor, Manager, Receptionist



## Rules:
An appointment must lie within a doctor's set schedule.

An appointment must be started under 2 hours of scheduled time, i.e if it was scheduled for 7:00pm, you can not start it after 9:00pm, unless you want to specify that time, it can be a feature added in future.

A doctor can only add appointment data to their own appointments.

A patient's information is only visible to doctor that it has been added under the id of initially, but via referrals, via having atleast one appointment with that patient.

If the clinic's all_visibility is set to true, the patient initially is still added under a doctor's name, but all doctors
can see the patients information

## Why Rust?:
Because I am a broke student who can't afford a huge server yet (the app is on t3 small on AWS).



