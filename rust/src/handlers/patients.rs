use axum::{
    Extension, extract::Json,
    extract::Path
};

use rust_decimal::Decimal;
use serde::{Serialize,Deserialize};
use uuid::Uuid;
use tower_cookies::Cookies;
use validator::Validate; // Import the trait
use crate::database::db_driver::DatabaseDriver;
use crate::utils::StaffRole::{self, Doctor};
use crate::utils::{ApiError, BloodType, Gender, Neurotype};
use sqlx::{QueryBuilder};
use sqlx::postgres::Postgres;

use crate::utils::{get_user};

use aide::NoApi;
use schemars::JsonSchema;

use aide::axum::ApiRouter;
use aide::axum::routing::{get, post, patch};

pub fn patient_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/patients", post(add_patients).get(view_patients))
        .api_route("/patients/{patient_id}", get(view_patient).patch(update_patients).delete(delete_patients))
        .api_route("/patients/sensitive", post(add_patients_information))
        .api_route("/patients/sensitive/{patient_id}", patch(update_patients_information))
}   

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}


#[derive(Deserialize, Validate, JsonSchema)]
pub struct PatientInformation {

    pub doctor_id  : Option<uuid::Uuid>,

    #[validate(length(max=50, message = "First name cant be more than 50 chars"))]
    pub first_name : String,

    #[validate(length(max=50, message = "Last name cant be more than 50 chars"))]
    pub last_name  : String,

    #[validate(length(max=15, message = "Number can not be more than 15 chars"))]
    pub number     : String,

    pub gender     : Gender,

    pub email      : Option<String>

}

async fn add_patients(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    body : Json<PatientInformation>
    ) -> Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    let doctor_id : Uuid;

    if !matches!(user.user_role, StaffRole::Doctor | StaffRole::Receptionist | StaffRole::Manager) {
        return Err(ApiError::Unauthorized);
    };

    if user.user_role != Doctor {
        doctor_id = body.doctor_id.ok_or(ApiError::BadRequest("doctor_id is required".to_string()))?;
    } else {
        doctor_id = user.user_id
    };

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
    "CALL add_patients_to_clinics($1, $2, $3, $4, $5, $6)",
    doctor_id, body.first_name, body.last_name, body.number,
    body.gender as Gender, body.email
    )
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))

}


#[derive(Deserialize, JsonSchema)]
pub struct UpdatePatients {
    pub first_name : Option<String>,
    
    pub last_name  : Option<String>,
    
    pub number     : Option<String>,
    
    pub note       : Option<String>,
    
    pub email      : Option<String>,
    
    pub gender     : Option<String>
}

async fn update_patients(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(patient_id)       : Path<uuid::Uuid>,
    body                         : Json<UpdatePatients>,

    ) -> Result<Json<SuccessResponse>, ApiError> {

    if body.first_name.is_none()
        && body.last_name.is_none()
        && body.number.is_none()
        && body.note.is_none()
        && body.email.is_none()
        && body.gender.is_none()
    {
        return Err(ApiError::BadRequest("No fields to update".to_string()))
    }

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if !matches!(user.user_role, StaffRole::Doctor | StaffRole::Receptionist | StaffRole::Manager) {
        return Err(ApiError::Unauthorized);
    };

    let mut builder: QueryBuilder<Postgres> = QueryBuilder::new("UPDATE patients_in_clinics SET ");
    let mut fields = builder.separated(", ");

    if let Some(v) = &body.first_name { fields.push("first_name = "); fields.push_bind_unseparated(v); }
    if let Some(v) = &body.last_name  { fields.push("last_name = ");  fields.push_bind_unseparated(v); }
    if let Some(v) = &body.number     { fields.push("number = ");     fields.push_bind_unseparated(v); }
    if let Some(v) = &body.note       { fields.push("note = ");       fields.push_bind_unseparated(v); }
    if let Some(v) = &body.email      { fields.push("email = ");      fields.push_bind_unseparated(v); }
    if let Some(v) = &body.gender      { fields.push("gender = ");    fields.push_bind_unseparated(v); }

    builder.push(" WHERE id = ").push_bind(patient_id);

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    builder.build().execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


#[derive(Deserialize, Validate, JsonSchema)]
pub struct PatientSensitiveInformation{
    pub patient_id : uuid::Uuid,

    pub neurotype  : Option<Neurotype>,

    pub blood_type : Option<BloodType>,

    pub height_cm  : Option<Decimal>,
    
    pub weight_kg  : Option<Decimal>,

    #[validate(length(max=500, message = "note cant be more than 500 chars"))]
    pub note       : Option<String>,
}

async fn add_patients_information (
    Extension(db): Extension<DatabaseDriver>,
        NoApi(cookie)       : NoApi<Cookies>,
    body : Json<PatientSensitiveInformation>

) -> Result<Json<SuccessResponse>, ApiError> {
    
    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    if body.neurotype.is_none()
    && body.blood_type.is_none()
    && body.height_cm.is_none()
    && body.weight_kg.is_none()
    && body.note.is_none() {
        return Err(ApiError::BadRequest("Provide some fields".to_string()))
    }


    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if user.user_role != StaffRole::Doctor {
        return Err(ApiError::Unauthorized)
    };
    
    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
    "CALL add_patients_data($1, $2, $3, $4, $5, $6)",
    body.patient_id, body.neurotype as _, body.blood_type as _,
    body.height_cm, body.weight_kg, body.note
    )
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


async fn update_patients_information(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(patient_id)       : Path<uuid::Uuid>,
    body                         : Json<PatientSensitiveInformation>,

) -> Result<Json<SuccessResponse>, ApiError> {

    if body.neurotype.is_none()
        && body.blood_type.is_none()
        && body.height_cm.is_none()
        && body.weight_kg.is_none()
        && body.note.is_none()
    {
        return Err(ApiError::BadRequest("No fields to update".to_string()));
    }

    let user = get_user(&cookie)
        .map_err(|_| ApiError::Unauthorized)?;

    if user.user_role != StaffRole::Doctor {
        return Err(ApiError::Unauthorized);
    }

    let mut builder: QueryBuilder<Postgres> = QueryBuilder::new("UPDATE patients_sensitive_information SET ");
    let mut fields = builder.separated(", ");

    if let Some(v) = &body.neurotype  { fields.push("neurotype = ");  fields.push_bind_unseparated(v); }
    if let Some(v) = &body.blood_type { fields.push("blood_type = "); fields.push_bind_unseparated(v); }
    if let Some(v) = &body.height_cm  { fields.push("height_cm = ");  fields.push_bind_unseparated(v); }
    if let Some(v) = &body.weight_kg  { fields.push("weight_kg = ");  fields.push_bind_unseparated(v); }
    if let Some(v) = &body.note       { fields.push("note = ");       fields.push_bind_unseparated(v); }

    let mut conn = db.pool.acquire()
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    builder.push(" WHERE patient_id = ").push_bind(patient_id);
    builder.build().execute(&mut *conn)
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}


#[derive(Deserialize, Validate, Serialize, JsonSchema)]
pub struct ReturnPatient {
    pub patient_id   : Uuid,

    pub full_name    : String,

    pub phone_number : String,

    pub email        : Option<String>,

    pub gender       : Gender,

    pub neurotype    : Option<Neurotype>,

    pub blood_type   : Option<BloodType>,

    pub height_cm    : Option<rust_decimal::Decimal>,
    
    pub weight_kg    : Option<rust_decimal::Decimal>,

    pub note         : Option<String>,

}

#[derive(Deserialize, Serialize, JsonSchema)]
pub struct QuickReturnPatient {
    pub patient_id       : Uuid,

    pub full_name        : String,

    pub phone_number     : String,

    pub email            : Option<String>,

    pub gender           : Gender,
}

#[derive(Serialize, JsonSchema)]
#[serde(untagged)]
pub enum PatientsResponse {
    Doctor(Vec<ReturnPatient>),
    Staff(Vec<QuickReturnPatient>)
}

#[derive(Serialize, JsonSchema)]
#[serde(untagged)]
pub enum PatientResponse {
    Doctor(Option<ReturnPatient>),
    Staff(Option<QuickReturnPatient>)
}

async fn view_patients(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    ) -> Result<Json<PatientsResponse>, ApiError> {

    let user = get_user(&cookie)
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
            ReturnPatient,
            r#"
            SELECT patient_id   as "patient_id!",
                   full_name    as "full_name!",
                   phone_number as "phone_number!",
                   email        as "email",
                   gender       as "gender!: Gender",
                   neurotype    as "neurotype: Neurotype",
                   blood_type   as "blood_type: BloodType",
                   height_cm    as "height_cm",
                   weight_kg    as "weight_kg",
                   note         as "note"
            FROM view_patients_as_doctors
            "#
            )
            .fetch_all(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
            Ok(Json(PatientsResponse::Doctor(p)))
        }

        StaffRole::Manager => {
        let p= sqlx::query_as!(
            QuickReturnPatient,
            r#"
            SELECT patient_id   as "patient_id!",
                   full_name    as "full_name!",
                   phone_number as "phone_number!",
                   email        as "email!",
                   gender       as "gender!: Gender"
            FROM view_patients_as_staff
            "#
            )
            .fetch_all(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
        
        Ok(Json(PatientsResponse::Staff(p)))
        
        }

        _ => return Err(ApiError::Unauthorized)
    }
}

async fn view_patient(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(patient_id)       : Path<uuid::Uuid>,
) -> Result<Json<PatientResponse>, ApiError> {

    let user = get_user(&cookie)
        .map_err(|_| ApiError::Unauthorized)?;

    if !matches!(user.user_role, StaffRole::Doctor | StaffRole::Manager) {
        return Err(ApiError::Unauthorized);
    }

    let mut conn = db.pool.acquire()
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
        .await
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    match user.user_role {
        StaffRole::Doctor => {
            let p = sqlx::query_as!(
                ReturnPatient,
                r#"
                SELECT patient_id  as  "patient_id!",
                   full_name       as  "full_name!",
                   phone_number    as  "phone_number!",
                   email           as  "email",
                   gender          as  "gender!: Gender",
                   neurotype       as  "neurotype: Neurotype",
                   blood_type      as  "blood_type: BloodType",
                   height_cm       as  "height_cm",
                   weight_kg       as  "weight_kg",
                   note            as  "note"
            FROM view_patients_as_doctors
            WHERE patient_id = $1
            "#, patient_id
            )
            .fetch_optional(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            Ok(Json(PatientResponse::Doctor(p)))
        }

        StaffRole::Manager => {
            let p = sqlx::query_as!(
                QuickReturnPatient,
                r#"
                SELECT patient_id  as "patient_id!",
                    full_name      as "full_name!",
                    phone_number   as "phone_number!",
                    email          as "email!",
                    gender         as "gender!: Gender"
                FROM view_patients_as_staff
                WHERE patient_id = $1
                "#, patient_id
            )
            .fetch_optional(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            Ok(Json(PatientResponse::Staff(p)))
        }

        _ => Err(ApiError::Unauthorized)
    }
}



async fn delete_patients(
    Extension(db): Extension<DatabaseDriver>,
        NoApi(cookie)       : NoApi<Cookies>,
    Path(patient_id): Path<uuid::Uuid>,
    ) -> Result<Json<SuccessResponse>, ApiError> {

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
        "DELETE FROM patients_in_clinics WHERE patient_id = $1",
        patient_id
    )
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}