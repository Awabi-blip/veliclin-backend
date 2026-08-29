// use crate::database::db_driver::DatabaseDriver;
// use crate::utils::StaffRole;
// use axum::{Extension, extract::Query, http::StatusCode, response::Redirect};
// use jsonwebtoken::{EncodingKey, Header, encode};
// use oauth2::{
//     AuthUrl, AuthorizationCode, ClientId, ClientSecret, CsrfToken, PkceCodeChallenge,
//     PkceCodeVerifier, RedirectUrl, Scope, TokenResponse, TokenUrl, basic::BasicClient,
//     reqwest::async_http_client,
// };
// use serde::Deserialize;
// use std::env;
// use std::time::{SystemTime, UNIX_EPOCH};
// use time::Duration;
// use tower_cookies::Cookie;

// // Your custom database driver (assumed to be in scope)
// // use your_crate::DatabaseDriver;

// pub fn google_oauth_client() -> BasicClient {
//     BasicClient::new(
//         ClientId::new(env::var("GOOGLE_CLIENT_ID").expect("Missing GOOGLE_CLIENT_ID")),
//         Some(ClientSecret::new(
//             env::var("GOOGLE_CLIENT_SECRET").expect("Missing GOOGLE_CLIENT_SECRET"),
//         )),
//         AuthUrl::new("https://accounts.google.com/o/oauth2/auth".to_string()).unwrap(),
//         Some(TokenUrl::new("https://oauth2.googleapis.com/token".to_string()).unwrap()),
//     )
//     .set_redirect_uri(
//         RedirectUrl::new("http://localhost:3000/auth/google/callback".to_string()).unwrap(),
//     )
// }

// // Step 1: /auth/google
// pub async fn google_login(
//     Extension(db): Extension<DatabaseDriver>,
//     Extension(oauth_client): Extension<BasicClient>, // Passed from Axum router setup
// ) -> Result<Redirect, StatusCode> {
//     // 1. Generate the PKCE challenge and verifier
//     let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();
//     // 2. Build the Google Auth URL and get the state (csrf_token)
//     let (auth_url, csrf_token) = oauth_client
//         .authorize_url(CsrfToken::new_random)
//         .add_scope(Scope::new("openid".to_string()))
//         .add_scope(Scope::new("profile".to_string()))
//         .add_scope(Scope::new("email".to_string()))
//         .set_pkce_challenge(pkce_challenge)
//         .url();

//     // 3. Save to database using ? instead of unwrap() or closures!
//     let mut conn = db
//         .pool
//         .acquire()
//         .await
//         .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

//     sqlx::query!(
//         "INSERT INTO oauth_states (state, verifier) VALUES ($1, $2)",
//         csrf_token.secret(),
//         pkce_verifier.secret()
//     )
//     .execute(&mut *conn)
//     .await
//     .map_err(|e| {
//         eprintln!("DB Error: {:?}", e);
//         StatusCode::INTERNAL_SERVER_ERROR
//     })?;

//     Ok(Redirect::to(auth_url.as_ref()))
// }

// // Step 2: /auth/google/callback
// #[derive(Deserialize)]
// pub struct CallbackQuery {
//     code: String,
//     state: String,
// }

// // Minimal user info shape returned by Google's userinfo endpoint
// #[derive(Deserialize)]
// pub struct GoogleUserInfo {
//     sub: String,
//     name: String,
//     email: String,
// }

// #[derive(sqlx::FromRow, Debug)]
// struct UserInfo {
//     user_id: uuid::Uuid,
//     user_role: Option<StaffRole>,
//     onboarded: bool,
// }

// use crate::utils::{SessionClaims, ProfileBuildClaims, InvitationClaims};
// //for jwt claims

// #[derive(Deserialize, Debug)]
// #[serde(tag = "cookie")] // This is the magic part
// pub enum AuthResponse {
//     ProfileBuild {
//         id: uuid::Uuid,
//     },

//     Invitation {
//         id: uuid::Uuid,
//         onboarded: bool,

//     },

//     Session {
//         id: uuid::Uuid,
//         staff_role: StaffRole,
//     },
// }

// pub async fn google_callback(
//     Query(query): Query<CallbackQuery>,
//     Extension(db): Extension<DatabaseDriver>,
//     Extension(oauth_client): Extension<BasicClient>, // <--- THIS LINE
// ) -> Result<Redirect, Redirect> {
//     // Look up the verifier using the state
//     let jwt_secret: String = env::var("JWT_SECRET").unwrap();

//     let mut conn = db
//         .pool
//         .acquire()
//         .await
//         .map_err(|_| Redirect::to("/google_login?error=db_error"))?;

//     let verifier_row = sqlx::query!(
//         "SELECT verifier FROM oauth_states WHERE state = $1 AND expires_at < now()",
//         query.state
//     )
//     .fetch_optional(&mut *conn)
//     .await
//     .map_err(|e| {
//         eprintln!("Database error looking up state: {:?}", e);
//         Redirect::to("/google_login?error=db_error")
//     })?
//     .ok_or_else(|| Redirect::to("/google_login?error=invalid_state"))?;

//     let pkce_verifier = PkceCodeVerifier::new(row.verifier.clone());

//     // Exchange the code + verifier for an access token
//     // generate_token returns Result<String, OauthError> — the raw access token
//     let token_result = oauth_client
//         .exchange_code(AuthorizationCode::new(query.code))
//         .set_pkce_verifier(pkce_verifier)
//         .request_async(async_http_client) // Uses reqwest under the hood!
//         .await
//         .map_err(|e| {
//             eprintln!("Token Exchange Error: {:?}", e);
//             Redirect::to("/google_login?error=access_token_error")
//         })?;

//     let access_token = token_result.access_token().secret();

//     // oauth_axum doesn't fetch user info — do it yourself with reqwest
//     let user_info: GoogleUserInfo = reqwest::Client::new()
//         .get("https://www.googleapis.com/oauth2/v3/userinfo")
//         .bearer_auth(access_token)
//         .send()
//         .await
//         .map_err(|_| Redirect::to("/google_login?error=reqwest_error"))?
//         .json()
//         .await
//         .map_err(|_| Redirect::to("/google_login?error=json_error"))?;

//     let auth: AuthResponse = sqlx::query_scalar!(
//         "SELECT * FROM register_user($1, $2, $3, $4)",
//         &user_info.sub,
//         &user_info.name,
//         &user_info.email,
//         query.state
//     )
//     .fetch_one(&mut *conn)
//     .await
//     .map_err(|_| Redirect::to("/google_login?error=db_error"))?;

//     let mut redirect_page: String;

//     match auth {
//         AuthResponse::ProfileBuild { id } => {
//             let expiry: u64 = SystemTime::now()
//                 .duration_since(UNIX_EPOCH)
//                 .unwrap()
//                 .as_secs() as u64
//                 + 60 * 60 * 24;

//             let token: String = encode(
//                 &Header::default(),
//                 &ProfileBuildClaims {
//                     user_id: id,
//                     exp: expiry,
//                 },
//                 &EncodingKey::from_secret(jwt_secret.as_bytes()),
//             )
//             .unwrap();

//             let mut cookie = Cookie::new("ProfileBuildCookie", token);
//             cookie.set_path("/");
//             cookie.set_http_only(true);
//             cookie.set_secure(true);
//             cookie.set_max_age(Duration::hours(24));

//             redirect_page = String::from("/profile_build")
//         }

//         AuthResponse::Session {
//             id,
//             staff_role,
//         } => {
//             let expiry: u64 = SystemTime::now()
//                 .duration_since(UNIX_EPOCH)
//                 .unwrap()
//                 .as_secs() as u64
//                 + 60 * 60 * 8;

//             let token = encode(
//                 &Header::default(),
//                 &SessionClaims {
//                     user_id: id,
//                     user_role: staff_role,
//                     exp: expiry,
//                 },
//                 &EncodingKey::from_secret(jwt_secret.as_bytes()),
//             )
//             .unwrap();

//             redirect_page = String::from("/dashboard");

//             let mut cookie = Cookie::new("SessionCookie", token);
//             cookie.set_path("/");
//             cookie.set_http_only(true);
//             cookie.set_secure(true);
//             cookie.set_max_age(Duration::hours(8));
//         }
//         AuthResponse::Invitation { id, onboarded } => {
//             let expiry: u64 = SystemTime::now()
//                 .duration_since(UNIX_EPOCH)
//                 .unwrap()
//                 .as_secs() as u64
//                 + 60 * 60 * 24 * 7;

//             let token = encode(
//                 &Header::default(),
//                 &InvitationClaims {
//                     user_id: id,
//                     onboarded: onboarded,
//                     exp: expiry,
//                 },
//                 &EncodingKey::from_secret(jwt_secret.as_bytes()),
//             )
//             .unwrap();

//             if onboarded == false {
//                 redirect_page = String::from("/onboarding");
//             } else {
//                 redirect_page = String::from("/create_clinic");
//             }
//             let mut cookie = Cookie::new("SessionCookie", token);
//             cookie.set_path("/");
//             cookie.set_http_only(true);
//             cookie.set_secure(true);
//             cookie.set_max_age(Duration::hours(8));
//         }
//     }
//     Ok(Redirect::to(&redirect_page))
// }
