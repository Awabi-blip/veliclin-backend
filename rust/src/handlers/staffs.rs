use axum::{
    Extension, extract::Json,
    extract::Path
};

use serde::{Serialize,Deserialize};
use tower_cookies::{Cookies};
use crate::database::db_driver::DatabaseDriver;
use crate::utils::{ApiError, ClinicType, StaffRole, get_user, get_user_id_for_invitation};
use validator::ValidateEmail;

use aide::NoApi;
use schemars::JsonSchema;

use aide::axum::ApiRouter;
use aide::axum::routing::{get, post, delete};

pub fn staff_invitation_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/staff/invitations", post(send_invitation).get(view_invitations))
        .api_route("/staff/{staff_id}", delete(remove_staff_from_clinic))
        .api_route("/staff/invitations/{invitation_id}", get(view_invitation).post(accept_invitation).delete(reject_invitation))
}

#[derive(Serialize, JsonSchema)]
pub struct SuccessResponse {
    pub message : String
}

#[derive(Deserialize, JsonSchema)]
pub struct InvitationInformation {
    pub receiver_email : String,
    pub role_invited_for : StaffRole
}

pub async fn send_invitation(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,

    body : Json<InvitationInformation>
) -> Result<Json<SuccessResponse>, ApiError> {

    if !body.receiver_email.validate_email() {
        return Err(ApiError::BadRequest("The email is invalid".to_string()))
    }

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    if !user.owner || !matches!(user.user_role, StaffRole::Manager)  {
        return Err(ApiError::Unauthorized)
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!("CALL send_invitations($1, $2::e_staff_role)",
    body.receiver_email,
    body.role_invited_for as _)
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

pub async fn remove_staff_from_clinic(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(staff_id) : Path<uuid::Uuid>
) -> Result<Json<SuccessResponse>, ApiError> {

    let user = get_user(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    if !user.owner || !matches!(user.user_role, StaffRole::Manager)  {
        return Err(ApiError::Unauthorized)
    }

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    // Procedure Params:
    // remove_staff_from_clinics(v_victim_id UUID)

    sqlx::query!("CALL remove_staff_from_clinics($1)", staff_id)
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

#[derive(Serialize, JsonSchema)]
pub struct Invitations{
    pub invitation_id     : i32,

    pub clinic_name       : String,

    pub clinic_type       : ClinicType,

    pub city_clinic_is_in : String,

    pub role_invited_for  : StaffRole,

    pub invited_by        : String
}

async fn view_invitations(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
) -> Result<Json<Vec<Invitations>>, ApiError> {
    let user_id = get_user_id_for_invitation(&cookie)
    .map_err(|_| ApiError::NotFound("user not found".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let rows = sqlx::query_as!(
        Invitations,
        r#"
        SELECT
            invitation_id AS "invitation_id!",
            clinic_name AS "clinic_name!",
            clinic_type AS "clinic_type!: ClinicType",
            city_clinic_is_in AS "city_clinic_is_in!",
            role_invited_for AS "role_invited_for!: StaffRole",
            invited_by AS "invited_by!"
        FROM view_invitations
        "#
    )
    .fetch_all(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(rows))
}

#[derive(Serialize, JsonSchema)]
pub struct Invitation{
    pub clinic_name       : String,

    pub clinic_type       : ClinicType,

    pub city_clinic_is_in : String,

    pub role_invited_for  : StaffRole,

    pub invited_by        : String
}

async fn view_invitation(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(invitation_id): Path<i32>
) -> Result<Json<Invitation>, ApiError> {
    let user_id = get_user_id_for_invitation(&cookie)
    .map_err(|_| ApiError::NotFound("user not found".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let row = sqlx::query_as!(
        Invitation,
        r#"
        SELECT
            clinic_name AS "clinic_name!",
            clinic_type AS "clinic_type!: ClinicType",
            city_clinic_is_in AS "city_clinic_is_in!",
            role_invited_for AS "role_invited_for!: StaffRole",
            invited_by AS "invited_by!"
        FROM view_invitations 
        WHERE invitation_id = $1
        "#,
        invitation_id
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| match e {
        sqlx::Error::RowNotFound => ApiError::NotFound("invitation not found".to_string()),
        e => ApiError::InternalServerError(e.to_string()),
    })?;

    Ok(Json(row))
}

async fn accept_invitation(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(invitation_id): Path<i32>
) -> Result<Json<SuccessResponse>, ApiError> {

    let user_id = get_user_id_for_invitation(&cookie)
    .map_err(|_| ApiError::NotFound("user not found".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    sqlx::query!("CALL accept_invitations($1)",
    invitation_id)
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}

async fn reject_invitation(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie)       : NoApi<Cookies>,
    Path(invitation_id): Path<i32>
) -> Result<Json<SuccessResponse>, ApiError> {

    let user_id = get_user_id_for_invitation(&cookie)
    .map_err(|_| ApiError::NotFound("user not found".to_string()))?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    // Procedure Parms:
    // create or replace procedure reject_invitations(
    //  f_invitation_id INT)

    sqlx::query!("CALL reject_invitations($1)",
    invitation_id)
    .execute(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    Ok(Json(SuccessResponse {
        message: "Success".to_string()
    }))
}