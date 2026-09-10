use axum::{response::{IntoResponse, Response}, http::StatusCode, Json};

use serde::{Serialize,Deserialize};
use uuid::Uuid;
use tower_cookies::{Cookie,Cookies};
use tower_cookies::cookie::SameSite;
use std::env;
use sqlx::{Type};
use jsonwebtoken::{decode, EncodingKey, DecodingKey, Validation, Algorithm, encode, Header};
use chrono::{Utc};
use schemars::JsonSchema;
use std::sync::OnceLock;
use resend_rs::Resend;
use std::time::{SystemTime, UNIX_EPOCH};
use time::Duration;

#[derive(Deserialize, Serialize)]
pub struct SessionClaims{
    pub user_id : uuid::Uuid,
    pub user_role : StaffRole,
    pub clinic_id : uuid::Uuid,
    pub owner : bool,
    pub exp : u64
}

#[derive(Deserialize, Serialize)]
pub struct PaymentClaims{
    pub user_id : uuid::Uuid,
    // pub expires_at : chrono::DateTime<Utc>,
    pub owner   : bool,
    pub exp : u64
}

#[derive(Deserialize, Serialize)]
pub struct User{
   pub user_id : uuid::Uuid,
   pub user_role : StaffRole,
   pub clinic_id    : uuid::Uuid,
   pub owner     : bool
}

#[derive(Clone, Copy, Serialize, Deserialize, Type, JsonSchema)]
#[sqlx(type_name = "e_gender")]
pub enum Gender {
    Male,
    Female
}

#[derive(Clone, Copy, Serialize, Deserialize, Debug, Type, PartialEq, JsonSchema)]
#[sqlx(type_name = "e_staff_role")]
pub enum StaffRole {
    Receptionist,
    Owner,
    Doctor,
    Manager,

}

#[derive(Clone, Copy, Type, Serialize, Deserialize, JsonSchema)]
#[sqlx(type_name = "e_clinic_type")]
pub enum ClinicType {
    #[sqlx(rename = "General_Clinic")]
    GeneralClinic,
    
    #[sqlx(rename = "Dental_Clinic")]
    DentalClinic,

    #[sqlx(rename = "Maternity_Home")]
    MaternityHome,

    #[sqlx(rename = "CMW_Clinic")]
    CMWClinic,

    #[sqlx(rename = "Nursing_Home")]
    NursingHome,

    #[sqlx(rename = "Homeopathic_Clinic")]
    HomeopathicClinic,

    #[sqlx(rename = "Tibb_Clinic")]
    TibbClinic,

    #[sqlx(rename = "Physiotherapy_Clinic")]
    PhysiotherapyClinic,

    #[sqlx(rename = "Rehabilitation_Centre")]
    RehabilitationCentre,

    #[sqlx(rename = "Aesthetic_Clinic")]
    AestheticClinic,

    #[sqlx(rename = "Diagnostic_Laboratory")]
    DiagnosticLaboratory,

    #[sqlx(rename = "Radiological_Imaging_Centre")]
    RadiologicalImagingCentre,

    #[sqlx(rename = "Dialysis_Centre")]
    DialysisCentre,

    #[sqlx(rename = "Lithotripsy_Centre")]
    LithotripsyCentre
}

#[derive(Clone, Copy, serde::Serialize, Deserialize, Type, JsonSchema)]
#[sqlx(type_name = "e_neurotype")]
pub enum Neurotype {
    Typical,
    ASD,
    ADHD,
    OCD,
    Dyslexia,
    Dyspraxia,
    Dyscalculia,
    Dysgraphia
}

#[derive(Clone, Copy, Type, Serialize, Deserialize, JsonSchema)]
#[sqlx(type_name = "e_blood_type")]
pub enum BloodType {
    #[sqlx(rename = "A+")]
    #[serde(rename = "A+")]
    APos,

    #[sqlx(rename = "A-")]
    #[serde(rename = "A-")]
    ANeg,

    #[sqlx(rename = "B+")]
    #[serde(rename = "B+")]
    BPos,

    #[sqlx(rename = "B-")]
    #[serde(rename = "B-")]
    BNeg,

    #[sqlx(rename = "AB+")]
    #[serde(rename = "AB+")]
    AbPos,

    #[sqlx(rename = "AB-")]
    #[serde(rename = "AB-")]
    AbNeg,

    #[sqlx(rename = "O+")]
    #[serde(rename = "O+")]
    OPos,

    #[sqlx(rename = "O-")]
    #[serde(rename = "O-")]
    ONeg,
}


#[derive(Clone, Copy, Serialize, Deserialize, Type, JsonSchema)]
#[sqlx(type_name = "e_working_days")]
pub enum WorkingDays{
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday
}

static PERMENANT_APP_DATA: OnceLock<PermenantAppData> = OnceLock::new();

pub fn get_permenant_app_data() -> &'static PermenantAppData {
    PERMENANT_APP_DATA.get_or_init(||{
       
        let jwt_secret  : String = env::var("JWT_SECRET").expect("JWT_SECRET must be set");
        let clerk_issuer: String = env::var("CLERK_ISSUER").expect("CLERK_ISSUER not set");
        let clerk_jwt_key: String = env::var("CLERK_JWT_KEY").expect("CLERK_JWT_KEY not set");
        let clerk_authorized_party: String = env::var("CLERK_AUTHORIZED_PARTY").expect("CLERK_AUTHORIZED_PARTY not set");

        
        let jwt_encoding_key: EncodingKey = EncodingKey::from_secret(jwt_secret.as_bytes());
        let jwt_decoding_key : DecodingKey = DecodingKey::from_secret(jwt_secret.as_bytes());
        let clerk_decoding_key = DecodingKey::from_rsa_pem(clerk_jwt_key.as_bytes());
        
        let mut clerk_validation: Validation = Validation::new(Algorithm::RS256);
        clerk_validation.validate_nbf = true;
        clerk_validation.set_issuer(&[clerk_issuer.as_str()]);
        clerk_validation.set_required_spec_claims(&["exp", "nbf", "iss", "sub"]);

        let resend_api_key : String = env::var("RESEND_API_KEY").expect("RESEND_API_KEY not set");
        
        let resend: Resend = Resend::new(
        &resend_api_key
            );

    let clerk_decoding_key = DecodingKey::from_rsa_pem(clerk_jwt_key.as_bytes())
    .expect("Clerk Key not set");
        return PermenantAppData {
            jwt_secret,
            jwt_encoding_key,
            jwt_decoding_key,
            clerk_decoding_key,
            clerk_validation,
            clerk_authorized_party,
            resend

        }
    }
)
}


pub struct PermenantAppData {
    pub jwt_secret             : String,
    pub jwt_encoding_key       : EncodingKey,
    pub jwt_decoding_key       : DecodingKey,
    pub clerk_decoding_key     : DecodingKey,
    pub clerk_validation       : Validation,
    pub clerk_authorized_party : String,
    pub resend                 : Resend,
}


pub fn get_user(cookies: &Cookies) -> Result<User, ApiError> {

    let creds  = get_permenant_app_data();
    
    let cookie = cookies.get("SessionCookie")
    .ok_or(ApiError::Unauthorized)?;

    let token_data: jsonwebtoken::TokenData<SessionClaims> = decode::<SessionClaims>(
            cookie.value(),
            &creds.jwt_decoding_key,
            &Validation::default(),
        )
        .map_err(|_| ApiError::Unauthorized)?;

    let user = User {
        user_id  : token_data.claims.user_id,
        clinic_id : token_data.claims.clinic_id,
        user_role: token_data.claims.user_role,
        owner    : token_data.claims.owner
    };
    
    Ok(user) 
    
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct InvitationClaims {
    pub user_id: uuid::Uuid,
    pub onboarded: bool,
    pub exp : u64
}

pub fn get_user_id_for_invitation(cookies: &Cookies) -> Result<Uuid, ApiError> {

    let creds  = get_permenant_app_data();

    let cookie = cookies.get("InvitationCookie")
    .ok_or(ApiError::Unauthorized)?;

    let token_data: jsonwebtoken::TokenData<InvitationClaims> = decode::<InvitationClaims>(
            cookie.value(),
            &creds.jwt_decoding_key,
            &Validation::default(),
        )
        .map_err(|_| ApiError::Unauthorized)?;

    Ok(token_data.claims.user_id) 
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProfileBuildClaims {
    pub user_id: Uuid,
    pub exp: u64,
}

pub fn get_user_id_for_profile_build(cookie: &Cookies) -> Result<Uuid, ApiError> {

    let creds  = get_permenant_app_data();

    let cookie = cookie.get("ProfileBuildCookie")
    .ok_or(ApiError::Unauthorized)?;

    let token_data: jsonwebtoken::TokenData<ProfileBuildClaims> = decode::<ProfileBuildClaims>(
            cookie.value(),
            &creds.jwt_decoding_key,
            &Validation::default(),
        )
        .map_err(|_| ApiError::Unauthorized)?;
    
    Ok(token_data.claims.user_id)
}

pub fn get_user_id_for_payment(cookie: &Cookies) -> Result<Uuid, ApiError> {

    let creds  = get_permenant_app_data();

    let cookie = cookie.get("PaymentCookie")
    .ok_or(ApiError::Unauthorized)?;

    let token_data: jsonwebtoken::TokenData<PaymentClaims> = decode::<PaymentClaims>(
            cookie.value(),
            &creds.jwt_decoding_key,
            &Validation::default(),
        )
        .map_err(|_| ApiError::Unauthorized)?;
    
    Ok(token_data.claims.user_id)
}

#[derive(Debug, thiserror::Error, aide::OperationIo)]
#[aide(output)]
pub enum ApiError {
    #[error("unauthorized")]
    Unauthorized,
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("not found: {0}")]
    NotFound(String),
    
    #[error("Internel Server Error:{0}")]
    InternalServerError(String),
    
    #[error("Database error")]
    Database(sqlx::Error),

    #[error("Cache error")]
    Cache(#[from] fred::error::Error),

}


impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        if let sqlx::Error::Database(db_err) = &err {
            if db_err.code().as_deref() == Some("P2001") {
                return ApiError::BadRequest(db_err.message().to_string());
            }
        }

        ApiError::Database(err)
    }
}

#[derive(Serialize)]
struct ErrorBody {
    message: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            ApiError::Unauthorized => (StatusCode::UNAUTHORIZED, "Unauthorized".to_string()),
            ApiError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            ApiError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            
            ApiError::InternalServerError(err) => {
                tracing::error!(error = ?err, "some weird bug");
                (StatusCode::INTERNAL_SERVER_ERROR, err)},
            
            ApiError::Database(err) => {
                tracing::error!(error = ?err, "database error");
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error".to_string())
            },   

            ApiError::Cache(err) => {
                tracing::error!(error = ?err, "valkey error");
                (StatusCode::INTERNAL_SERVER_ERROR, "Internel serve error".to_string())
            }
        }
        
        ;

        (status, Json(ErrorBody { message })).into_response()
    }
}


#[derive(Deserialize, Debug)]
#[serde(tag = "cookie")] 
pub enum AuthResponse {
    ProfileBuild {
        id: uuid::Uuid,
    },
    Invitation {
        id: uuid::Uuid,
        onboarded: bool,
    },
    Session {
        id: uuid::Uuid,
        staff_role: StaffRole,
        clinic_id: uuid::Uuid,
        owner: bool,
        expires_at : chrono::DateTime<Utc>
    },
}

#[derive(Serialize, Deserialize)]
pub struct GeneralLoginClaims {
    pub user_id: uuid::Uuid,
    pub exp: u64,
}


pub fn match_auth(
    auth    : AuthResponse,
    cookies : &Cookies

) -> Result<String, ApiError> {

    let redirect_page: String;

    let app_data = get_permenant_app_data();

    match auth {
    AuthResponse::ProfileBuild { id } => {
        let expiry: u64 = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
        + 60 * 60 * 24;

        let token: String = encode(
        &Header::default(),
        &ProfileBuildClaims {
            user_id: id,
            exp: expiry,
        },
        &app_data.jwt_encoding_key,
        )
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

        let mut cookie = Cookie::new("ProfileBuildCookie", token);
        cookie.set_path("/");
        cookie.set_http_only(true);
        cookie.set_secure(true);
        cookie.set_same_site(SameSite::Lax);
        cookie.set_max_age(Duration::hours(24));
        cookies.add(cookie);

        let general_token: String = encode(
        &Header::default(),
        &GeneralLoginClaims {
            user_id: id,
            exp: expiry,
            },
            &app_data.jwt_encoding_key,
        )
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

        let mut general_cookie =  Cookie::new("GeneralLoginCookie", general_token);
        
        general_cookie.set_path("/");
        general_cookie.set_http_only(true);
        general_cookie.set_secure(true);
        general_cookie.set_same_site(SameSite::Lax);
        general_cookie.set_max_age(Duration::hours(24));

        cookies.add(general_cookie);

        redirect_page = String::from("/profile_build");
    }

    AuthResponse::Session { id, staff_role, clinic_id, owner, expires_at } => {
        let now = chrono::Utc::now();
        let duration: u64;
        
        if expires_at > now {

            let diff = expires_at - now;

            if diff.num_hours() < 8 {
                duration = diff.num_hours() as u64
            } else {
                duration = 8
            }

            let expiry: u64 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
            + 60 * 60 * duration;
            
            let token = encode(
            &Header::default(),
            &SessionClaims {
                user_id: id,
                user_role: staff_role,
                clinic_id : clinic_id,
                owner: owner,
                exp: expiry,
            },
            &app_data.jwt_encoding_key,
            )
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;


            let mut cookie = Cookie::new("SessionCookie", token);
            cookie.set_path("/");
            cookie.set_http_only(true);
            cookie.set_secure(true);
            cookie.set_same_site(SameSite::Lax);
            cookie.set_max_age(Duration::hours(8));
            cookies.add(cookie);

            let general_token: String = encode(
            &Header::default(),
            &GeneralLoginClaims {
                user_id: id,
                exp: expiry,
                },
                &app_data.jwt_encoding_key,
            )
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            let mut general_cookie =  Cookie::new("GeneralLoginCookie", general_token);
            
            general_cookie.set_path("/");
            general_cookie.set_http_only(true);
            general_cookie.set_secure(true);
            general_cookie.set_same_site(SameSite::Lax);
            general_cookie.set_max_age(Duration::hours(24));

            cookies.add(general_cookie);

            redirect_page = String::from("/dashboard");
        } else { 
            let expiry: u64 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
            + 60 * 60 * 8;
            let token = encode(
                &Header::default(),
                &PaymentClaims {
                    user_id         : id,
                    owner           : owner,
                    exp             : expiry,
                },
                &app_data.jwt_encoding_key,
            )
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;


            let mut cookie = Cookie::new("PaymentCookie", token);
            cookie.set_path("/");
            cookie.set_http_only(true);
            cookie.set_secure(true);
            cookie.set_same_site(SameSite::Lax);
            cookie.set_max_age(Duration::hours(8));
            cookies.add(cookie);

            let general_token: String = encode(
            &Header::default(),
            &GeneralLoginClaims {
                user_id: id,
                exp: expiry,
                },
                &app_data.jwt_encoding_key,
            )
            .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

            let mut general_cookie =  Cookie::new("GeneralLoginCookie", general_token);
            
            general_cookie.set_path("/");
            general_cookie.set_http_only(true);
            general_cookie.set_secure(true);
            general_cookie.set_same_site(SameSite::Lax);
            general_cookie.set_max_age(Duration::hours(24));

            cookies.add(general_cookie);            

            redirect_page = String::from("/payment");


        }

    }

    AuthResponse::Invitation { id, onboarded } => {
        let expiry: u64 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
            + 60 * 60 * 24 * 7;

        let token = encode(
            &Header::default(),
            &InvitationClaims {
                user_id: id,
                onboarded,
                exp: expiry,
            },
            &app_data.jwt_encoding_key,
        )
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

        let mut cookie = Cookie::new("InvitationCookie", token);
        cookie.set_path("/");
        cookie.set_http_only(true);
        cookie.set_secure(true);
        cookie.set_same_site(SameSite::Lax);
        cookie.set_max_age(Duration::hours(8));
        cookies.add(cookie);

        let general_token: String = encode(
        &Header::default(),
        &GeneralLoginClaims {
            user_id: id,
            exp: expiry,
            },
            &app_data.jwt_encoding_key,
        )
        .map_err(|e| ApiError::InternalServerError(e.to_string()))?;

        let mut general_cookie =  Cookie::new("GeneralLoginCookie", general_token);
        
        general_cookie.set_path("/");
        general_cookie.set_http_only(true);
        general_cookie.set_secure(true);
        general_cookie.set_same_site(SameSite::Lax);
        general_cookie.set_max_age(Duration::hours(24));

        cookies.add(general_cookie);

        redirect_page = if onboarded {
            String::from("/create_clinic")
        } else {
            String::from("/onboarding")
        };
    }
}

    Ok(redirect_page)

}