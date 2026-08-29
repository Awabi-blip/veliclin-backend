use crate::database::db_driver::DatabaseDriver;
use crate::utils::{get_permenant_app_data, AuthResponse, match_auth};
use axum::{Extension, Json, response::Redirect,};
use jsonwebtoken::{decode, encode, Header};
use serde::Deserialize;
use std::time::{SystemTime, UNIX_EPOCH};
use time::Duration;
use tower_cookies::{Cookie, Cookies};
use tower_cookies::cookie::SameSite;
use chrono::{Utc};
use aide::axum::ApiRouter;
use axum::routing::post;


pub fn auth_routes() -> ApiRouter {
    ApiRouter::new()
        .route("/auth/clerk/callback", post(clerk_callback))
}

#[derive(Deserialize)]
pub struct AuthPayload {
    access_token: String,
}

#[derive(Deserialize)]
pub struct ClerkClaims {
    sub: String,
    
    #[serde(rename = "primaryEmail")]
    email: String,
    
    #[serde(rename = "fullName")]
    full_name: Option<String>,
    
    #[serde(default)]
    azp: Option<String>,
    
    #[serde(default)]
    sts: Option<String>,
}

pub async fn clerk_callback(
    Extension(db) : Extension<DatabaseDriver>,
    cookie      : Cookies,
    Json(payload) : Json<AuthPayload>,
) -> Result<Redirect, Redirect> {

    let app_data = get_permenant_app_data();

    let token_data = decode::<ClerkClaims>(
        &payload.access_token,
        &app_data.clerk_decoding_key,
        &app_data.clerk_validation,
    )
    .map_err(|e: jsonwebtoken::errors::Error| {
        tracing::error!("Clerk token verification failed: {:?}", e);
        Redirect::to("/login?error=invalid_token")
    })?;

    if let Some(authorized_party) = &token_data.claims.azp {
        if authorized_party != &app_data.clerk_authorized_party {
            tracing::error!(
                "Rejected Clerk token with unexpected authorized party: {}",
                authorized_party
            );
            return Err(Redirect::to("/login?error=invalid_token"));
        }
    }

    if token_data.claims.sts.as_deref() == Some("pending") {
        tracing::error!("Rejected Clerk token with pending session status");
        return Err(Redirect::to("/login?error=invalid_token"));
    }

    let mut conn = db
        .pool
        .acquire()
        .await
        .map_err(|e| {
            tracing::error!("DB connection error: {:?}", e);
            Redirect::to("/login?error=db_error")
        })?;

    let full_name = token_data
        .claims
        .full_name
        .unwrap_or_else(|| "User".to_string());

    let sqlx::types::Json(auth): sqlx::types::Json<AuthResponse> = sqlx::query_scalar!(
        r#"SELECT register_users($1, $2, $3) AS "response!: sqlx::types::Json<AuthResponse>""#,
        &token_data.claims.sub,
        &full_name,
        &token_data.claims.email,
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| {
        tracing::error!("register_user error: {:?}", e);
        Redirect::to("/login?error=db_error")
    })?;

    
    cookie.list().into_iter().for_each(|c| {
    cookie.remove(Cookie::build(c.name().to_string()).path("/").build())
        });

    let redirect_page = match_auth(auth, &cookie)
    .map_err(|_| Redirect::to("/login?error=internal_error"))?;


    Ok(Redirect::to(&redirect_page))
}
