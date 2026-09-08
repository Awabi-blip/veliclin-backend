use axum::{
    Extension, extract::Json,
    extract::Path
};

use serde::{Serialize,Deserialize};
use uuid::Uuid;
use tower_cookies::{Cookies};
use crate::database::db_driver::DatabaseDriver;
use crate::utils::StaffRole;
use crate::utils::{WorkingDays, ApiError};
use chrono::NaiveTime;
use crate::utils::{get_user};

use aide::NoApi;
use schemars::JsonSchema;
use aide::axum::ApiRouter;
use aide::axum::routing::{get, post};

pub fn doctor_schedule_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/doctors/schedules", post(add_doctor_schedule))
        .api_route("/doctors/{doctor_id}/schedules", get(view_doctors_schedule))
        .api_route("/doctors/schedules/delete", post(delete_doctors_schedule))
}

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}

#[derive(Deserialize, JsonSchema)]
pub struct ScheduleInformation {
    pub doctor_id         : uuid::Uuid,
    pub day_shift_starts  : WorkingDays,
    pub time_shift_starts : NaiveTime,
    pub time_shift_ends   : NaiveTime,
}


#[tracing::instrument(skip(db, cookie, body), err(Debug))]
pub async fn add_doctor_schedule(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    body : Json<ScheduleInformation>
) -> Result<Json<SuccessResponse>, ApiError> {

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if !matches!(user.user_role, StaffRole::Manager | StaffRole::Doctor) {
        return Err(ApiError::Unauthorized)
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL insert_doctors_schedule($1, $2::e_working_days, $3, $4)",
        body.doctor_id,
        body.day_shift_starts as _,
        body.time_shift_starts,
        body.time_shift_ends
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

#[derive(Serialize, sqlx::Type, JsonSchema)]
pub struct ReturnDoctorSchedule {
    pub schedule_id : i64,

    pub doctor_id: Uuid,

    pub time_shift_starts: NaiveTime,

    pub day_shift_starts: WorkingDays,

    pub time_shift_ends: NaiveTime,

    pub day_shift_ends: WorkingDays,
}


#[tracing::instrument(skip(db, cookie), err(Debug))]
pub async fn view_doctors_schedule(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(doctor_id)              : Path<uuid::Uuid>
) -> Result<Json<Vec<ReturnDoctorSchedule>>, ApiError> {

    let user = get_user(&cookie)
    .map_err(|_| ApiError::NotFound("You were not found in our database".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let rows = sqlx::query_as!(
        ReturnDoctorSchedule,
        r#"SELECT 
        schedule_id, 
        doctor_id, 
        time_shift_starts,
        day_shift_starts as "day_shift_starts: WorkingDays",
        time_shift_ends,
        day_shift_ends as "day_shift_ends: WorkingDays"
        FROM doctors_schedule 
        WHERE doctor_id = $1"#, 
        doctor_id
    ).fetch_all(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(rows))
}

#[derive(Deserialize, JsonSchema)]
pub struct DeleteSchedule {
    pub schedule_id : i64,

    pub delete_appointments : bool
}

#[tracing::instrument(skip(db, cookie, body), err(Debug))]
pub async fn delete_doctors_schedule(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    body : Json<DeleteSchedule>
) -> Result<Json<SuccessResponse>, ApiError> {

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if !matches!(user.user_role, StaffRole::Manager | StaffRole::Doctor) {
        return Err(ApiError::Unauthorized)
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
    "CALL delete_doctor_schedule($1, $2)", 
    body.schedule_id, body.delete_appointments
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}