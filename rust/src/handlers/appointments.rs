use axum::{
    Extension,
    extract::Query, extract::Path, extract::Json
};

use serde::{Serialize,Deserialize};
use tower_cookies::{Cookies};
use validator::Validate; // Import the trait
use crate::database::db_driver::DatabaseDriver;
use crate::utils::StaffRole::{self, Doctor};
use crate::utils::{ApiError};
use sqlx::{Type};
use chrono::{Utc};
use rust_decimal_macros::dec;
use aide::NoApi;
use schemars::JsonSchema;
use crate::utils::{get_user};
use aide::axum::ApiRouter;
use aide::axum::routing::{get, post, patch, delete};

// in handlers/appointments.rs
pub fn appointment_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/appointments", post(create_appointment))
        .api_route("/appointments", get(view_appointments))
        .api_route("/appointments/{appointment_id}", patch(reschedule_appointment))
        .api_route("/appointments/{appointment_id}", delete(delete_appointments))
        .api_route("/appointments/{appointment_id}/start", post(start_appointment))
        .api_route("/appointments/data", post(add_data_to_appointments))
        .api_route("/appointments/{appointment_id}/data", patch(update_data_to_appointments))
}

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}

#[derive(Serialize, JsonSchema)]
#[serde(untagged)]
pub enum AppointmentsResponse {
    Doctor(Vec<ReturnAppointmentsForDoctors>),
    Staff(Vec<ReturnAppointmentsForStaff>)
}

#[derive(Validate, Deserialize, JsonSchema)]
pub struct AppoinmentInformation {
    pub doctor_id       : uuid::Uuid,
    pub patient_id      : uuid::Uuid,
    pub scheduled_at    : chrono::DateTime<Utc>,
    pub duration_hours  : rust_decimal::Decimal,

    #[validate(length(max=2048, message = "Meeting Links cannot be longer than 2048 characters"))]
    pub meeting_link    : String
}


#[axum::debug_handler]
pub async fn create_appointment(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookies): NoApi<Cookies>,
    body : Json<AppoinmentInformation>
    ) -> Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    let valid_hours: [rust_decimal::Decimal; 4] = [dec!(0.5), dec!(1.0), dec!(1.5), dec!(2.0)];
    
    if !valid_hours.contains(&body.duration_hours){
        return Err(ApiError::BadRequest("The hours must be in (0.5, 1, 1.5, 2) hours".to_string()))
    }

    let user = get_user(&cookies)
    .map_err(|_| ApiError::Unauthorized)?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL add_appointments($1, $2, $3, $4, $5)",
        body.doctor_id,
        body.patient_id,
        body.scheduled_at,
        body.duration_hours,
        body.meeting_link
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
    
    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))

}

#[derive(Validate, Deserialize, JsonSchema)]
pub struct UpdateAppointmentInformation {
    pub scheduled_at    : chrono::DateTime<Utc>,
    pub duration_hours  : rust_decimal::Decimal,

    #[validate(length(max = 2048, message = "Meeting Links cannot be longer than 2048 characters"))]
    pub meeting_link    : Option<String>
}


pub async fn reschedule_appointment(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookies)      : NoApi<Cookies>,
    Path(appointment_id)    : Path<i64>,
    body                         : Json<UpdateAppointmentInformation>,

    ) -> Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    let valid_hours: [rust_decimal::Decimal; 4] = [dec!(0.5), dec!(1.0), dec!(1.5), dec!(2.0)];
    
    if !valid_hours.contains(&body.duration_hours) {
        return Err(ApiError::BadRequest("The hours must be in (0.5, 1, 1.5, 2) hours".to_string()))
    }

    let user = get_user(&cookies)
        .map_err(|_| ApiError::Unauthorized)?;

    let mut conn = db.pool.acquire()
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL reschedule_appointment($1, $2, $3, $4)",
        appointment_id,
        body.scheduled_at,
        body.duration_hours,
        body.meeting_link
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


#[derive(Deserialize, Serialize, JsonSchema)]
pub struct ReturnAppointmentsForDoctors {
    pub patient_name   : String,
    pub appointment_id : i64,
    pub note           : Option<String>,
    pub diagnosis      : Option<String>,
    pub scheduled_at   : chrono::DateTime<chrono::Utc>,
    pub ends_at        : chrono::DateTime<chrono::Utc>,
    pub meeting_link   : Option<String>,
    pub fee            : Option<rust_decimal::Decimal>
}

#[derive(Deserialize, Serialize, JsonSchema)]
pub struct ReturnAppointmentsForStaff {
    pub doctor_name    : String,
    pub patient_name   : String,
    pub appointment_id : i64,
    pub scheduled_at   : chrono::DateTime<chrono::Utc>,
    pub ends_at        : chrono::DateTime<chrono::Utc>,
}


#[derive(Deserialize, Type, JsonSchema)]
#[sqlx(type_name = "e_appointment_status")]

pub enum AppointmentStatus {
    Scheduled,
    
    #[sqlx(rename = "On_going")]
    OnGoing,

    Completed,
    Cancelled,
}


#[derive(Deserialize, JsonSchema)]
pub struct AppointmentFilter {
    pub status: AppointmentStatus,
}

pub async fn view_appointments(
    Extension(db)   : Extension<DatabaseDriver>,
    NoApi(cookies)         : NoApi<Cookies>,
    Query(filter): Query<AppointmentFilter>,

) -> Result<Json<AppointmentsResponse>, ApiError> {
    
    let user = get_user(&cookies)
    .map_err(|_| ApiError::Unauthorized)?;


    if !matches!(user.user_role, StaffRole::Doctor | StaffRole::Manager 
        | StaffRole::Receptionist) {
        return Err(ApiError::Unauthorized);
    };

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    match user.user_role {
        StaffRole::Doctor => {
        let p = sqlx::query_as!(
            ReturnAppointmentsForDoctors,
            r#"SELECT 
            patient_name as "patient_name!",
            appointment_id as "appointment_id!",
            note,
            diagnosis,
            scheduled_at as "scheduled_at!",
            ends_at as "ends_at!",
            meeting_link,
            fee
            FROM view_appointments_as_doctors WHERE 
            status = $1::e_appointment_status"#, 
        filter.status as AppointmentStatus
        ).fetch_all(&mut *conn)
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
        
        Ok(Json(AppointmentsResponse::Doctor(p)))
    
    }

        StaffRole::Manager | StaffRole::Receptionist => {
            let p = sqlx::query_as!(
            ReturnAppointmentsForStaff,
            r#" 
            SELECT 
                doctor_name as "doctor_name!",
                patient_name as "patient_name!",
                appointment_id as "appointment_id!",
                scheduled_at as "scheduled_at!",
                ends_at as "ends_at!"
                FROM view_appointments_as_staffs WHERE 
                status = $1::e_appointment_status"#,
            filter.status as AppointmentStatus
            ).fetch_all(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
            
            Ok(Json(AppointmentsResponse::Staff(p)))
        }
        _ => return Err(ApiError::Unauthorized) 

    }


}


pub async fn start_appointment(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookies)               : NoApi<Cookies>,
    Path(appointment_id)    : Path<i64>,


) -> Result<Json<SuccessResponse>, ApiError> {
    
    let user = get_user(&cookies)
    .map_err(|_| ApiError::NotFound("User not found".to_string()))?;

    if !matches!(user.user_role, StaffRole::Manager | StaffRole::Doctor) {
        return Err(ApiError::Unauthorized);
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
   
   
    sqlx::query!(
        r#"UPDATE appointments
        SET status = 'On_going'::e_appointment_status
        WHERE appointment_id = $1
        "#, appointment_id
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

#[derive(Validate, Deserialize, JsonSchema)]
pub struct AppointmentData {
    pub appointment_id      : i64,
    
    #[validate(length(max=1000, message = "Notes cannot be longer than 
    1000 characters"))]
    pub note                : String,

    #[validate(length(max=500,  message = "Diagnosis cannot be longer than 
    500 characters"))]
    pub diagnosis           : String,
    
    pub fee                 : rust_decimal::Decimal
}


pub async fn add_data_to_appointments(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookies)               : NoApi<Cookies>,
    body                         : Json<AppointmentData>
    ) -> Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    let user = get_user(&cookies)
    .map_err(|_| ApiError::Unauthorized)?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL add_data_to_appointment($1, $2, $3, $4)",
        body.appointment_id, body.note, body.diagnosis, body.fee
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
    
    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


#[derive(Validate, Deserialize, JsonSchema)]
pub struct UpdateAppointmentData {    
    #[validate(length(max=1000, message = "Notes cannot be longer than 
    1000 characters"))]
    pub note                : Option<String>,

    #[validate(length(max=500,  message = "Diagnosis cannot be longer than 
    500 characters"))]
    pub diagnosis           : Option<String>,

    pub fee                 : Option<rust_decimal::Decimal>
}

pub async fn update_data_to_appointments(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookies)      : NoApi<Cookies>,
    Path(appointment_id)    : Path<i64>,
    body                         : Json<UpdateAppointmentData>,

    ) -> Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    if body.note.is_none() 
    && body.diagnosis.is_none()
    && body.fee.is_none() {
    return Err(ApiError::BadRequest("nothing to update".to_string()));
    }

    let user = get_user(&cookies)
    .map_err(|_| ApiError::Unauthorized)?;

    if user.user_role != Doctor {
        return Err(ApiError::Unauthorized)
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL add_data_to_appointment($1, $2, $3, $4)",
        appointment_id, body.note, body.diagnosis, body.fee
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
    
    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


pub async fn delete_appointments(
    Extension(db) : Extension<DatabaseDriver>,
    NoApi(cookies)                : NoApi<Cookies>,
    Path(appointment_id)     : Path<i64>,
) -> Result <Json<SuccessResponse>, ApiError> {
    
    let user = get_user(&cookies)
    .map_err(|_| ApiError::NotFound("user not found".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        r#"UPDATE appointments
        SET status = 'Cancelled'::e_appointment_status
        WHERE appointment_id = $1"#,
        appointment_id
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}
