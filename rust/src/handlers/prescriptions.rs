use axum::{
    Extension, extract::Json,
    extract::Query, extract::Path
};

use serde::{Serialize,Deserialize};
use sqlx::prelude::FromRow;
use uuid::Uuid;
use tower_cookies::{Cookies};

use crate::database::db_driver::DatabaseDriver;
use crate::utils::StaffRole::Doctor;
use crate::utils::{ApiError};
use sqlx::{QueryBuilder};
use sqlx::postgres::Postgres;
use chrono::{NaiveDate};
use crate::utils::{get_user};
use serde_json::Value;
use aide::NoApi;
use schemars::JsonSchema;
use aide::axum::ApiRouter;
use aide::axum::routing::{post, patch};

pub fn prescription_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/prescriptions", post(add_prescription).get(view_prescriptions))
        .api_route("/prescriptions/{prescription_id}", patch(update_prescription))
}

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}

#[derive(Serialize, Deserialize, JsonSchema)]
pub struct AddPrescriptionRequest {
    pub appointment_id  : i64,

    pub patient_id      : Uuid,

    pub medication      : String,

    pub potency         : String,

    pub frequency       : String,

    pub start_date      : Option<NaiveDate>,   // has db default

    pub end_date        : NaiveDate,

    pub metadata        : Option<Value>,
}


#[tracing::instrument(skip(db, cookie, info), err(Debug))]
pub async fn add_prescription (
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    info                         : Json<AddPrescriptionRequest>
)  -> Result<Json<SuccessResponse>, ApiError>{

    let user = get_user(&cookie)
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
        "CALL add_prescriptions($1, $2, $3, $4, $5, $6, $7, $8)",
        info.appointment_id,
        info.patient_id,
        info.medication,
        info.potency,
        info.frequency,
        info.end_date,
        info.start_date,
        info.metadata
    )
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
pub struct PrescriptionRecord {
    pub prescription_id : i64,
    
    pub patient_name: String,
   
    pub doctor_name: String,
    
    pub medication: String,
    
    pub potency: String,
    
    pub frequency: String,
    
    pub start_date: NaiveDate,
    
    pub end_date: NaiveDate,
   
    pub meta_data: Option<Value>,  // JSONB + nullable

}

#[derive(Debug, Deserialize, JsonSchema)]
pub enum PrescriptionStatus {
    OnGoing,
    Completed
}

#[tracing::instrument(skip(db, cookie), err(Debug))]
pub async fn view_prescriptions(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Query(filter): Query<PrescriptionStatus>,

) -> Result<Json<Vec<PrescriptionRecord>>, ApiError> {

    let user = get_user(&cookie)
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

    let prescriptions = match filter {
        PrescriptionStatus::OnGoing => {
            sqlx::query_as!(
                PrescriptionRecord,
                r#"SELECT 
                    prescription_id  as  "prescription_id!",
                    patient_name     as  "patient_name!",
                    doctor_name      as  "doctor_name!",
                    medication       as  "medication!",
                    potency          as  "potency!",
                    frequency        as  "frequency!",
                    start_date       as  "start_date!",
                    end_date         as  "end_date!",
                    meta_data
                FROM view_prescriptions 
                WHERE end_date > CURRENT_DATE"#
            )
            .fetch_all(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?
        },
        PrescriptionStatus::Completed => {
            sqlx::query_as!(
                PrescriptionRecord,
                r#"SELECT 
                    prescription_id as "prescription_id!",
                    patient_name as "patient_name!",
                    doctor_name as "doctor_name!",
                    medication as "medication!",
                    potency as "potency!",
                    frequency as "frequency!",
                    start_date as "start_date!",
                    end_date as "end_date!",
                    meta_data
                FROM view_prescriptions 
                WHERE end_date <= CURRENT_DATE"#
            )
            .fetch_all(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?
        },
    };

    Ok(Json(prescriptions))
}

#[derive(Deserialize, FromRow, JsonSchema)]
pub struct UpdatePrescription {
    pub medication: Option<String>,

    pub potency:    Option<String>,

    pub frequency:  Option<String>,

    pub end_date:   Option<NaiveDate>,

    pub meta_data:  Option<Value>,
}


#[tracing::instrument(skip(db, cookie, info), err(Debug))]
pub async fn update_prescription(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(prescription_id)   : Path<i64>,
    info                         : Json<UpdatePrescription>,

) -> Result<Json<SuccessResponse>, ApiError> {

    if info.medication.is_none()
        && info.potency.is_none()
        && info.frequency.is_none()
        && info.end_date.is_none()
        && (info.meta_data.is_none() || info.meta_data.as_ref().map_or(true, |v| {
            // Check if it's not an object, OR if all values inside the object are Null
            v.as_object().map_or(true, |obj| obj.values().all(|val| val.is_null()))
        }))
    {
        return Err(ApiError::BadRequest("No fields to update".to_string()))
    }

    let user = get_user(&cookie)
        .map_err(|_| ApiError::Unauthorized)?;

    if user.user_role != Doctor {
        return Err(ApiError::Unauthorized)
    }

    let mut builder: QueryBuilder<Postgres> = QueryBuilder::new("UPDATE patient_prescriptions SET ");
    let mut fields = builder.separated(", ");

    if let Some(v) = &info.medication { fields.push("medication = "); fields.push_bind_unseparated(v); }
    if let Some(v) = &info.potency    { fields.push("potency = ");    fields.push_bind_unseparated(v); }
    if let Some(v) = &info.frequency  { fields.push("frequency = ");  fields.push_bind_unseparated(v); }
    if let Some(v) = info.end_date    { fields.push("end_date = ");   fields.push_bind_unseparated(v); }
    if let Some(v) = &info.meta_data  { fields.push("meta_data = ");  fields.push_bind_unseparated(v); }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    builder.push(" WHERE id = ").push_bind(prescription_id);
    builder.build().execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}