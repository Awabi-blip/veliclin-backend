use axum::{
    Extension, extract::Json,
    extract::State, response::Redirect, extract::Path
};

use chrono::{DateTime, Utc};
use fred::prelude::*;
use tower_cookies::{Cookies};
use validator::Validate; // Import the trait
use crate::database::db_driver::DatabaseDriver;
use crate::utils::{ClinicType, StaffRole, get_user, get_permenant_app_data, User, AuthResponse, match_auth};
use rustrict::{CensorStr, Type};
use crate::utils::{get_user_id_for_invitation, ApiError};
use rand::Rng;
use aide::NoApi;
use schemars::JsonSchema;
use serde::Serialize;
use aide::axum::ApiRouter;
use aide::axum::routing::post;
use chrono_tz::Tz;
use resend_rs::types::{CreateEmailBaseOptions};


pub fn clinics_routes() -> ApiRouter<Client>{
    ApiRouter::new()
        .api_route("/clinics", post(create_clinic))
        .api_route("/clinics/deletion/request", post(create_otp_delete_clinic))
        .api_route("/clinics/deletion/confirm", post(enter_otp_delete_clinic))
}

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}

#[derive(serde::Deserialize, Validate, JsonSchema)]
pub struct ClinicInformation{
    #[validate(length(max=100, message = "Clinic name cant be more than 100 chars"))]
    pub clinic_name    : String,

    pub clinic_type    : ClinicType,

    pub city           : String,

    #[validate(length(max=500, message = "Address cant be more than 500 chars"))]
    pub address        : String,

    #[validate(length(max=15, message = "Contact Number cant be more than 15 chars"))]
    pub contact_number : String,

    pub banner_url     : String,

    pub self_role      : Option<StaffRole>,

    pub all_visibility : bool,

    #[schemars(with = "String")] 
    pub timezone       : Tz
}

pub async fn create_clinic(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    body                         : Json<ClinicInformation>
) ->  Result<Redirect, ApiError> {

    let user_id = get_user_id_for_invitation(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if body.clinic_name.is(Type::INAPPROPRIATE){
        return Err(ApiError::BadRequest("Inappropriate clinic name".to_string()))
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;


    let sqlx::types::Json(auth): sqlx::types::Json<AuthResponse> = sqlx::query_scalar!(
        r#"
        SELECT create_new_clinic(
            $1, $2::e_clinic_type, $3, $4, $5, $6, $7, $8, $9::e_staff_role
        )
        AS "response!: sqlx::types::Json<AuthResponse>"
        "#,
        body.clinic_name,
        body.clinic_type as _,
        body.city,
        body.address,
        body.contact_number,
        body.banner_url,
        body.all_visibility,
        body.timezone.name(),
        body.self_role as _
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
                                        
    let redirect_page = match_auth(auth, &cookie)?;
    
    Ok(Redirect::to(&redirect_page))

}


#[derive(Serialize, Validate, JsonSchema)]
pub struct ViewClinicInformationStaff {
    pub clinic_name    : String,

    pub clinic_type    : ClinicType,

    pub city_name      : String,

    pub address        : String,

    pub contact_number : String,

    pub banner_url     : String,

    #[schemars(with = "String")] 
    pub timezone       : String
}

#[derive(Serialize, Validate, JsonSchema)]
pub struct ViewClinicInformationManager {
    pub clinic_name    : String,

    pub clinic_type    : ClinicType,

    pub city_name      : String,

    pub address        : String,

    pub contact_number : String,

    pub banner_url     : String,

    #[schemars(with = "String")] 
    pub timezone       : String,

    pub plan           : String,

    pub expires_at     : DateTime<Utc>,

    pub all_visibility : bool
}

#[derive(Serialize, JsonSchema)]
#[serde(untagged)]
pub enum ClinicResponse {
    Manager(ViewClinicInformationManager),
    Staff(ViewClinicInformationStaff)
}

pub async fn view_clinic(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(clinic_id)              : Path<uuid::Uuid>
) ->  Result<ClinicResponse, ApiError> {

    let auth = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, auth.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    match auth {
        User {
            owner: true,
            ..
        }
        | User {
            user_role: StaffRole::Owner | StaffRole::Manager,
            ..
        } => {
            let rows: ViewClinicInformationManager = sqlx::query_as!(
                ViewClinicInformationManager,
                r#"
                SELECT
                    clinic_name AS "clinic_name!",
                    clinic_type AS "clinic_type!: ClinicType",
                    city_name AS "city_name!",
                    address AS "address!",
                    contact_number AS "contact_number!",
                    banner_url AS "banner_url!",
                    timezone AS "timezone!: String",
                    plan::text AS "plan!",
                    expires_at AS "expires_at!",
                    all_visibility AS "all_visibility!"
                FROM clinics
                WHERE clinic_id = $1
                "#,
                clinic_id
            )
            .fetch_one(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            Ok(ClinicResponse::Manager(rows))
        }

        User {
            user_role: StaffRole::Doctor | StaffRole::Receptionist,
            ..
        } => {
            let rows = sqlx::query_as!(
                ViewClinicInformationStaff,
                r#"
                SELECT
                    clinic_name AS "clinic_name!",
                    clinic_type AS "clinic_type!: ClinicType",
                    city_name AS "city_name!",
                    address AS "address!",
                    contact_number AS "contact_number!",
                    banner_url AS "banner_url!",
                    timezone AS "timezone!: String"
                FROM clinics
                WHERE clinic_id = $1
                "#,
                clinic_id
            )
            .fetch_one(&mut *conn)
            .await
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            Ok(ClinicResponse::Staff(rows))
        }

}
}


#[derive(serde::Deserialize, Validate, JsonSchema)]
pub struct ConfirmationAnalysis {
    pub email    : String,
    // pub owner_id : uuid::Uuid
}

async fn create_otp_delete_clinic(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    State(vk)            : State<Client>

    ) ->  Result<Redirect, ApiError> {

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if user.user_role != StaffRole::Owner || !user.owner {
        return Err(ApiError::Unauthorized)
    };

    let value: u32 = rand::thread_rng().gen_range(100_000..1_000_000);

    let value = value.to_string();

    let key = format!("otp:{}", user.user_id);

    let app_data = get_permenant_app_data();

    let _: () = vk.set(&key, &value, Some(Expiration::EX(500)), None, false)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let cf = sqlx::query_as!(
        ConfirmationAnalysis,
        r#"SELECT app_users.email as email FROM app_users
        JOIN clinics ON app_users.id = clinics.owner_id
        WHERE id = $1"#,
        user.user_id
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let resend = &app_data.resend;

    let from = "Veliclin <no-reply@veliclin.com>";
    let to = [cf.email.as_str()];
    let subject = "Your OTP code for Veliclin";

    let html = format!(
    "<p>Your code is: <strong>{}</strong></p>",
    value
    );

    let email = CreateEmailBaseOptions::new(
        from,
        to,
        subject,
    )
    .with_html(&html);

    resend
    .emails
    .send(email)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;


    Ok(Redirect::to("/enter_otp_delete_clinic"))
}


#[derive(serde::Deserialize, Validate, JsonSchema)]
pub struct OtpClinicDeletion {

    #[validate(length(max=6, message = "Otp can not be more than 6 letters"))]
    pub otp : String
}

pub async fn enter_otp_delete_clinic(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    State(vk)            : State<Client>,
    Json(body): Json<OtpClinicDeletion>,

    ) ->  Result<Json<SuccessResponse>, ApiError> {

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
            
    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?; 

    if user.user_role != StaffRole::Owner || !user.owner {
        return Err(ApiError::Unauthorized)
    };

    let key = format!("otp:{}", user.user_id);

    let value: Option<String> = vk.get(&key)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let value = value.ok_or_else(
        || ApiError::NotFound("Clinic deletion not initialised".to_string())
    )?;    

    if value != body.otp {
        return Err(ApiError::BadRequest("The code does not match".to_string()))
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!(
        "CALL delete_clinics()"
    ).execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;


    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}