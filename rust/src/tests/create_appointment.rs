use crate::database::db_driver::DatabaseDriver;
use lettre::transport::smtp::commands::Data;
use sqlx::PgPool;
use uuid::Uuid;
use chrono::{DateTime, Utc, TimeZone, NaiveTime};
use crate::utils::WorkingDays;

async fn call_add_appointments(
    db: &DatabaseDriver,
    doctor_id: Uuid,
    patient_id: Uuid,
    scheduled_at: DateTime<Utc>,
    duration_hours: f64,
    meeting_link: &str,
) -> Result<(), sqlx::Error> {
    
    let mut conn = db.pool.acquire().await?;

    sqlx::query("CALL add_appointments($1, $2, $3, $4, $5)")
        .bind(doctor_id)
        .bind(patient_id)
        .bind(scheduled_at)
        .bind(duration_hours)
        .bind(meeting_link)
        .execute(&mut *conn)
        .await
        .map(|_| ())
}

async fn ensure_shift(
    db: &DatabaseDriver,
    doctor_id: Uuid,
    clinic_id: Uuid,
    start: NaiveTime,
    day: WorkingDays,          // your enum, e.g., WorkingDays::Monday
    end: NaiveTime,
) -> Result<(), sqlx::Error> {

    let mut txn = db.pool.begin().await?;

    let exists: Option<bool> = sqlx::query_scalar(
        "SELECT true FROM doctors_schedule
         WHERE doctor_id = $1 AND clinic_id = $2
           AND time_shift_starts = $3 AND day_shift_starts = $4"
    )
    .bind(doctor_id)
    .bind(clinic_id)
    .bind(start)
    .bind(day)               // binds the enum directly (works if WorkingDays: sqlx::Type)
    .fetch_optional(&mut *txn)
    .await?;


    if exists.is_none() {
        sqlx::query(
            "INSERT INTO doctors_schedule
             (doctor_id, doctor_role, clinic_id, time_shift_starts, day_shift_starts, time_shift_ends, timezone)
             VALUES ($1, 'Doctor', $2, $3, $4, $5, $6)"
        )
        .bind(doctor_id)
        .bind(clinic_id)
        .bind(start)
        .bind(day)
        .bind(end)
        .execute(&mut *txn)
        .await?;
        }
    txn.commit().await?;

    Ok(())
}

#[tokio::test]
async fn test_add_appointments_bad_paths() -> Result<(), sqlx::Error>{
    let db = DatabaseDriver::new().await.unwrap();
    let mut conn = db.pool.acquire().await.unwrap();

    let doctor_id: Uuid = "019f8cbb-caf8-7fb4-99e4-88421e1167c2".parse().unwrap();
    let patient_id: Uuid = "019fa632-8b75-7d11-bd7b-08433bf0f0d7".parse().unwrap();
    let clinic_id: Uuid = "019f8cc7-dac4-7568-ae80-c74982b31409".parse().unwrap();

    let _ = ensure_shift(&db, doctor_id, clinic_id,
    NaiveTime::from_hms_opt(8, 0, 0)
    .expect("invalid time"), 
    WorkingDays::Monday,
    NaiveTime::from_hms_opt(16, 0, 0).expect("invalid time")).await?;

    let _ = ensure_shift(&db, doctor_id, clinic_id,
    NaiveTime::from_hms_opt(8, 0, 0)
    .expect("invalid time"), 
    WorkingDays::Monday,
    NaiveTime::from_hms_opt(16, 0, 0).expect("invalid time")).await?;
    // Insert both shifts
    // ---- Regular shift (08:00-16:00) tests ----
    // 1. Before shift
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 7, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 0.5, "https://meet.example.com/test1").await;
    assert!(result.is_err(), "Expected failure for before-shift booking");

    // 2. After shift
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 17, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.0, "https://meet.example.com/test2").await;
    assert!(result.is_err(), "Expected failure for after-shift booking");

    // 3. Overrun
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 15, 30, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.5, "https://meet.example.com/test3").await;
    assert!(result.is_err(), "Expected failure for overrun booking");

    // 4. Wrong day (Tuesday, no regular shift)
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 28, 10, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.0, "https://meet.example.com/test4").await;
    assert!(result.is_err(), "Expected failure for day without shift");

    // 5. Invalid duration
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 9, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 0.75, "https://meet.example.com/test5").await;
    assert!(result.is_err(), "Expected failure for invalid duration");

    // ---- Overnight shift (22:00-06:00) tests ----
    // 6. Valid inside overnight (Monday 23:00 UTC)
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 23, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 0.5, "https://meet.example.com/night1").await;
    assert!(result.is_ok(), "Overnight booking should succeed");

    // 7. Valid inside overnight (Tuesday 05:00 UTC)
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 28, 5, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 0.5, "https://meet.example.com/night2").await;
    assert!(result.is_ok(), "Tuesday early booking inside shift should succeed");

    // 8. Starts before overnight, ends inside
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 21, 30, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.0, "https://meet.example.com/night3").await;
    assert!(result.is_err(), "Should fail: starts before shift");

    // 9. Starts inside overnight, ends after
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 28, 5, 30, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.0, "https://meet.example.com/night4").await;
    assert!(result.is_err(), "Should fail: ends after shift");

    // 10. Starts exactly at shift end (06:00) – should fail because it ends after shift
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 28, 6, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 0.5, "https://meet.example.com/night5").await;
    assert!(result.is_err(), "Should fail: starts at shift end and ends after");

    // 11. Unauthorized staff (invalid user_id)
    sqlx::query("SET myapp.user_id = '00000000-0000-0000-0000-000000000000'")
        .execute(&mut *conn)
        .await
        .unwrap();
    let scheduled = Utc.with_ymd_and_hms(2026, 7, 27, 9, 0, 0).unwrap();
    let result = call_add_appointments(&db, doctor_id, patient_id, scheduled, 1.0, "https://meet.example.com/test6").await;
    assert!(result.is_err(), "Expected failure for unauthorized staff");

    // Reset user_id
    sqlx::query("SET myapp.user_id = $1")
        .bind(doctor_id)
        .execute(&mut *conn)
        .await
        .unwrap();

    // Cleanup both inserted shifts
    sqlx::query("DELETE FROM doctors_schedule WHERE doctor_id = $1 AND clinic_id = $2")
        .bind(doctor_id)
        .bind(clinic_id)
        .execute(&mut *conn)
        .await
        .unwrap();
    Ok(())
}