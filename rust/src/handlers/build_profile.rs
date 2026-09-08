use axum::{
    Extension, extract::Json,
    response::Redirect, 

};

use aide::NoApi;
use schemars::JsonSchema;
use serde::{Deserialize};
use validator::Validate; // Import the trait
use chrono::{NaiveDate, Utc, Datelike}; // Import the plain date type
use crate::database::db_driver::DatabaseDriver;
use crate::utils::{ApiError, Gender, get_user_id_for_profile_build, AuthResponse, match_auth};
use rustrict::{CensorStr, Type};
use aide::axum::ApiRouter;
use aide::axum::routing::post;
use tower_cookies::{Cookie, Cookies};

pub fn profile_routes() -> ApiRouter {
    ApiRouter::new()
        .api_route("/profile", post(build_profile))
}


//write a function that takes query parameters, and builds a persons profile.
#[derive(Deserialize, Validate, JsonSchema)]
pub struct BuildProfile {
    #[validate(length(max=50, message = "First name cant be more than 50 chars"))]
    pub first_name: String,

    #[validate(length(max=50, message = "Last name cant be more than 50 chars"))]
    pub last_name: String,

    pub date_of_birth: NaiveDate,
    
    pub gender: Gender
}

#[tracing::instrument(skip(db, cookie, body), err(Debug))]
pub async fn build_profile(
    Extension(db): Extension<DatabaseDriver>,
    NoApi(cookie) : NoApi<Cookies>,    
    body : Json<BuildProfile>
) -> Result<Redirect, ApiError> {
    
    let user_id = get_user_id_for_profile_build(&cookie)
    .map_err(|_| ApiError::Unauthorized)?;

    let today = Utc::now().date_naive();
    let eighteen_years_ago = today.with_year(today.year() - 18).unwrap();

    body.validate()
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    
    if body.first_name.contains("  ") || body.last_name.contains("  ") {
        return Err(ApiError::BadRequest("First Name or Last Name cannot have a space".to_string()));
    }

    if body.first_name.is(Type::INAPPROPRIATE) || body.last_name.is(Type::INAPPROPRIATE) {
        return Err(ApiError::BadRequest("Inappropriate Name".to_string()));
    }

    if body.date_of_birth > eighteen_years_ago {
        return Err(ApiError::BadRequest("Can't be younger than 18".to_string()));
    }

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let sqlx::types::Json(auth): sqlx::types::Json<AuthResponse> =
    sqlx::query_scalar!(
        r#"
        SELECT create_profile($1, $2, $3, $4, $5)
        AS "response!: sqlx::types::Json<AuthResponse>"
        "#,
        user_id,
        body.first_name,
        body.last_name,
        body.gender as _,
        body.date_of_birth as _
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    cookie.remove(
        Cookie::build("ProfileBuildCookie")
        .path("/")
        .build()
    );


    let redirect_page = match_auth(auth, &cookie)?;

    Ok(Redirect::to(&redirect_page))

}
