use crate::database::db_driver::DatabaseDriver;
use uuid::Uuid;
use chrono::NaiveTime;
use crate::utils::WorkingDays;

async fn call_insert_schedule(
    db: &DatabaseDriver,
    staff_id: Uuid,
    doctor_id: Uuid,
    day: WorkingDays,          // must implement sqlx::Type (cast to e_working_days)
    start: NaiveTime,
    end: NaiveTime,
) -> Result<(), sqlx::Error> {
    let mut conn = db.pool.acquire().await?;

    // Mimic the cookie session by setting the current user
    sqlx::query("SET myapp.user_id = $1")
        .bind(staff_id)
        .execute(&mut *conn)
        .await?;

    // Call the procedure used by the Axum handler
    sqlx::query("CALL insert_doctors_schedule($1, $2::e_working_days, $3, $4)")
        .bind(doctor_id)
        .bind(day)
        .bind(start)
        .bind(end)
        .execute(&mut *conn)
        .await?;

    Ok(())
}

#[tokio::test]
async fn overlap_partial_start_should_fail() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // Overlaps start of 08:00-16:00 (Mon 07:30-08:30)
    let result = call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Monday,
        NaiveTime::from_hms_opt(7, 30, 0).unwrap(),
        NaiveTime::from_hms_opt(8, 30, 0).unwrap(),
    ).await;

    assert!(result.is_err());
    Ok(())
}

#[tokio::test]
async fn overlap_partial_end_should_fail() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // Overlaps end of 08:00-16:00 (Mon 15:30-16:30)
    let result = call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Monday,
        NaiveTime::from_hms_opt(15, 30, 0).unwrap(),
        NaiveTime::from_hms_opt(16, 30, 0).unwrap(),
    ).await;

    assert!(result.is_err());
    Ok(())
}

#[tokio::test]
async fn overlap_overnight_start_should_fail() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // Overlaps start of overnight (Mon 21:00-23:00)
    let result = call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Monday,
        NaiveTime::from_hms_opt(21, 0, 0).unwrap(),
        NaiveTime::from_hms_opt(23, 0, 0).unwrap(),
    ).await;

    assert!(result.is_err());
    Ok(())
}

#[tokio::test]
async fn valid_before_morning_shift_should_succeed() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // Completely before 08:00-16:00 (Mon 06:00-07:30)
    call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Monday,
        NaiveTime::from_hms_opt(6, 0, 0).unwrap(),
        NaiveTime::from_hms_opt(7, 30, 0).unwrap(),
    ).await?;

    // Optional verification: check it exists (could be done, but not required by the ask)
    Ok(())
}

#[tokio::test]
async fn valid_after_overnight_shift_should_succeed() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // After overnight ends at 06:00 (Tue 07:00-09:00)
    call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Tuesday,
        NaiveTime::from_hms_opt(7, 0, 0).unwrap(),
        NaiveTime::from_hms_opt(9, 0, 0).unwrap(),
    ).await?;

    Ok(())
}

#[tokio::test]
async fn overlap_tuesday_early_morning_inside_overnight_should_fail() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await?;
    let staff_id: Uuid = "019f8caa-a51a-7e7f-8208-403bc23616b8".parse().unwrap();
    let doctor_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    // Tuesday 01:00–03:00 falls inside the Mon 22:00–Tue 06:00 overnight shift → must fail
    let result = call_insert_schedule(
        &db,
        staff_id,
        doctor_id,
        WorkingDays::Tuesday,
        NaiveTime::from_hms_opt(1, 0, 0).unwrap(),
        NaiveTime::from_hms_opt(3, 0, 0).unwrap(),
    ).await;

    assert!(result.is_err());
    Ok(())
}