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

## Rules:
An appointment must lie within a doctor's set schedule.

A patient's information is only visible to doctor that it has been added under the id of initially, but via referrals, 
other doctors can see that patient.

If the clinic's all_visibility is set to true, the patient initially is still added under a doctor's name, but all doctors
can see the patients information

## Why Rust?:
Because I am a broke student who can't afford a huge server yet (the app is on t3 small on AWS).



