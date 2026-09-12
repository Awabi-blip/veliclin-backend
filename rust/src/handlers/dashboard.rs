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
    .await?;

    db.set_rls(&mut conn, user.user_id)
    .await?;
    let key = format!("dashboard:{}", user.clinic_id);

    let cached_response: Result<Option<String>, Error> = vk.get(&key)
    .await;

    match cached_response {
        
        Err(e) => {
            tracing::warn!("dashboard redis GET failed, skipping cache: {}", e);
            // fall through — treat this like a cache miss, rest of the function still runs
        }
        
        Ok(cached_response) => {
            if let Some(cached_response) = cached_response {
                
                match serde_json::from_str::<serde_json::Value>(&cached_response) {
                    Ok(cached_response) => {
                        return Ok(Json(DashboardResponse {
                            dashboard_response: cached_response,
                        }));
                    }
                    Err(e) => {
                        tracing::warn!("dashboard cache deserialize failed, skipping cache: {}", e);
                        // fall through instead of ?-propagating — a corrupt cache entry
                        // shouldn't take down the whole request
                    }
                }
            }
            // None => cache miss, just fall through
        }
    }

    let result: serde_json::Value = sqlx::query_scalar!(
        r#"
        SELECT * FROM return_dashboard_response() AS "return_dashboard_response!"
        "#
    )
    .fetch_one(&mut *conn)
    .await?;

    vk.set::<(), _, _>(&key, result.to_string(), Some(Expiration::EX(300)), None, false)
    .await?;

     Ok(Json(DashboardResponse {
                dashboard_response: result
            }))


}




// a json build object is better for this
// directly from postgres