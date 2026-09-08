use axum::{
    extract::{Extension, State},
    Json,
};

use schemars::JsonSchema;
use tower_cookies::{Cookies};
use serde::{Serialize};
use crate::database::db_driver::DatabaseDriver;
use crate::utils::{ApiError, get_user};
use aide::axum::ApiRouter;
use aide::axum::routing::{get};
use fred::types::Expiration;
use aide::NoApi;
use fred::prelude::*;

pub fn dashboard_routes() -> ApiRouter<Client> {
    ApiRouter::new()
        .api_route("/dashboard", get(load_dashboard))

}   

#[derive(Serialize, JsonSchema)]
pub struct DashboardResponse {
    dashboard_response: serde_json::Value,
}

// create a function
// takes 

#[tracing::instrument(skip(db, cookie), err(Debug))]
pub async fn load_dashboard(
    Extension(db) : Extension<DatabaseDriver>,
    NoApi(cookie) : NoApi<Cookies>,    
    State(vk)     : State<Client>

) -> Result<Json<DashboardResponse>, ApiError> {

    let user = get_user(&cookie)?;

    let mut conn = db.pool.acquire()
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    db.set_rls(&mut conn, user.user_id)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    let key = format!("dashboard:{}", user.clinic_id);

    let cached_response: Option<String> =
     vk.get(&key)
    .await
    .map_err(|e| ApiError::InternalServerError(
        format!("dashboard redis GET: {}", e)
    ))?;

    if let Some(cached_response) = cached_response {

        let cached_response: serde_json::Value = serde_json::from_str(&cached_response)
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;
    
       return  Ok(Json(DashboardResponse {
        dashboard_response: cached_response
        }))

    }

    let result: serde_json::Value = sqlx::query_scalar!(
        r#"
        SELECT * FROM return_dashboard_response() AS "return_dashboard_response!"
        "#
    )
    .fetch_one(&mut *conn)
    .await
    .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

    vk.set::<(), _, _>(&key, result.to_string(), Some(Expiration::EX(300)), None, false)
    .await
    .map_err(|e| ApiError::InternalServerError(
        format!("dashboard redis SET: {}", e)
        ))?;


     Ok(Json(DashboardResponse {
                dashboard_response: result
            }))


}




// a json build object is better for this
// directly from postgres