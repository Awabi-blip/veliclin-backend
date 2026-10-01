// src/main.rs
mod database;
mod handlers;
mod utils;
mod auth;
mod logging;
mod tests;
use dotenvy::dotenv;
use fred::prelude::*;
use fred::types::ExpireOptions;


use database::db_driver::DatabaseDriver;
// use auth::google_sso::{google_oauth_client, google_login, google_callback};
use axum::{Extension, extract::Request, extract::State,
middleware::{self,Next}, response::Response, Json};
use crate::utils::{ApiError, get_generel_login_cookie};
use aide::{
    axum::{ApiRouter, IntoApiResponse},
    openapi::OpenApi,
    swagger::Swagger,
};

use aide::axum::routing::get;

use crate::handlers::appointments::appointment_routes;
use crate::handlers::build_profile::profile_routes;
use crate::handlers::dashboard::dashboard_routes;
use crate::handlers::clinics::clinics_routes;
use crate::handlers::doctors_schedule::doctor_schedule_routes;
use crate::handlers::patients::patient_routes;
use crate::handlers::prescriptions::prescription_routes;
use crate::handlers::staffs::staff_invitation_routes;
use crate::auth::clerk::auth_routes;
use tower_cookies::{CookieManagerLayer, Cookies, Cookie};
use tower_http::cors::CorsLayer;
use axum::http::{header, HeaderValue, Method};


async fn serve_api(Extension(api): Extension<OpenApi>) -> impl IntoApiResponse {
    Json(api)
}

#[tokio::main]
async fn main() {
    dotenv().ok();

    let _guard = logging::init_logging(); 
    tracing::info!("server starting up");
    
    let db = DatabaseDriver::new().await.expect("failed to connect");
    let config = Config::default(); // points to 127.0.0.1:6379 by default
    
    let vk_client = Builder::from_config(config)
    .build()
    .expect("failed to connect");
    
    vk_client.connect();

    vk_client.wait_for_connect()
    .await
    .expect("failed to connect");

    let mut api = OpenApi::default();

    let app = ApiRouter::new()
    .route("/docs", Swagger::new("/api.json").axum_route())
    .route("/api.json", get(serve_api))   // <-- was missing
    .merge(auth_routes())
    .merge(profile_routes())
    .merge(clinics_routes().with_state(vk_client.clone()))  // supply Client state right here
    .merge(dashboard_routes().with_state(vk_client.clone()))
    .merge(staff_invitation_routes())
    .merge(appointment_routes())
    .merge(doctor_schedule_routes()) 
    .merge(patient_routes())
    .merge(prescription_routes())
    .layer(Extension(db))
    .layer(CookieManagerLayer::new())
    .layer(middleware::from_fn_with_state(
        vk_client.clone(),
        rate_limiter,
    ))
    .layer(
        CorsLayer::new()
            .allow_origin(
                "https://www.veliclin.com"
                    .parse::<HeaderValue>()
                    .unwrap(),
            )
            .allow_methods([
                Method::GET,
                Method::POST,
                Method::PUT,
                Method::PATCH,
                Method::DELETE,
                Method::OPTIONS,
            ])
            .allow_headers([
                header::CONTENT_TYPE,
                header::AUTHORIZATION,
            ])            
            .allow_credentials(true),
    );

    
    //copy trait is just making a new reference to the heap

    let app = app
        .finish_api(&mut api)
        .layer(Extension(api))
        .into_make_service();

    let listener = tokio::net::TcpListener::bind("127.0.0.1:8000")
    .await
    .expect("could not bind the ip address to listener");
    
    axum::serve(listener, app)
    .await
    .expect("server could not start!");
}

async fn rate_limiter(
    State(vk_client): State<Client>,
    cookies : Cookies,
    req:Request, 
    next:Next,

) -> Result<Response, ApiError> {

    let user_ip = req
    .headers()
    .get("x-forwarded-for")
    .and_then(|v: &axum::http::HeaderValue| v.to_str().ok())
    .and_then(|s| s.split(',').next())
    .map(str::trim)
    .unwrap_or("127.0.0.1")
    .to_owned(); 

    let user_id = get_generel_login_cookie(&cookies)?;

    let ip_key = format!("rl:{user_ip}");
    let id_key = format!("rl:id:{user_id}");

    let trx = vk_client.multi();

    let _: () = trx.incr(&ip_key)
    .await?;

    let _: () = trx.incr(&id_key)
    .await?;
    
    let _: () = trx.expire(&ip_key, 60, Some(ExpireOptions::NX))
    .await?;

    let _: () = trx.expire(&id_key, 60, Some(ExpireOptions::NX))
    .await?;

    let (ip_value, id_value, _,_): (i64, i64, bool, bool) = trx.exec(false)
    .await?;

    if (ip_value > 60) || (id_value > 60) {
        return Err(ApiError::BadRequest("Too many requests".to_string()))
    }

    let response = next.run(req).await;

    Ok(response)

}