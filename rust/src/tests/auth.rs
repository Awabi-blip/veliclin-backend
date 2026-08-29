use uuid::Uuid;
use crate::database::db_driver::DatabaseDriver;
use crate::utils::{ApiError, StaffRole};
use crate::auth::clerk::AuthResponse;

pub enum AuthOutcome {
    ProfileBuild,
    Dashboard,
    Payment,
    CreateClinic,
    Onboarding,
}

pub async fn determine_auth_outcome(
    db: &DatabaseDriver,
    sub: String,
    full_name: String,
    email: String,
) -> Result<(AuthResponse, AuthOutcome), sqlx::Error> {

    let mut conn = db.pool.acquire().await?;

    let sqlx::types::Json(auth): sqlx::types::Json<AuthResponse> = sqlx::query_scalar!(
        r#"SELECT register_users($1, $2, $3) AS "response!: sqlx::types::Json<AuthResponse>""#,
        sub,
        full_name,
        email,
    )
    .fetch_one(&mut *conn)
    .await?;

    let outcome = match auth {
        AuthResponse::ProfileBuild { .. } => AuthOutcome::ProfileBuild,
        AuthResponse::Session { expires_at, staff_role, owner, .. } => {
            if expires_at > chrono::Utc::now() {
                AuthOutcome::Dashboard
            } else {
                AuthOutcome::Payment
            }
        }
        AuthResponse::Invitation { onboarded, .. } => {
            if onboarded {
                AuthOutcome::CreateClinic
            } else {
                AuthOutcome::Onboarding
            }
        }
    };

    Ok((auth, outcome))
}

#[cfg(test)]
#[tokio::test]
async fn test_owner_expired_session_returns_payment() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new()
    .await
    .unwrap(); // leave, unless its error type is sqlx::Error
    let mut conn = db.pool.acquire().await?;

    sqlx::query!(
        "UPDATE clinics SET expires_at = expires_at - INTERVAL '1 Hour'
        WHERE owner_id = (SELECT id FROM app_users WHERE email = 'zoha_queen@gmail.com')"
    )
    .execute(&mut *conn)
    .await?;

    let (auth, outcome) = determine_auth_outcome(
        &db,
        "3".into(),
        "Zoha".into(),
        "zoha_queen@gmail.com".into(),
    )
    .await?;

    match auth {
        AuthResponse::Session { staff_role, owner, .. } => {
            assert!(matches!(staff_role, StaffRole::Owner));
            assert!(owner);
        }
        _ => panic!("Expected Session response"),
    }

    assert!(matches!(outcome, AuthOutcome::Payment));
    Ok(())
}

#[tokio::test]
async fn test_manager_session_dashboard() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await.unwrap();

    let (auth, outcome) = determine_auth_outcome(
        &db,
        "1".into(),
        "Awabi".into(),
        "awabhero34@gmail.com".into(),
    )
    .await?;

    match auth {
        AuthResponse::Session { staff_role, owner, .. } => {
            assert!(matches!(staff_role, StaffRole::Manager));
            assert!(owner);
        }
        _ => panic!("Expected Session response"),
    }

    assert!(matches!(outcome, AuthOutcome::Dashboard));
    Ok(())
}

#[tokio::test]
async fn test_doctor_session_dashboard_no_owner() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await.unwrap();

    let (auth, outcome) = determine_auth_outcome(
        &db,
        "4".into(),
        "Ayesha".into(),
        "ayesha_lol@gmail.com".into(),
    )
    .await?;

    match auth {
        AuthResponse::Session { staff_role, owner, .. } => {
            assert!(matches!(staff_role, StaffRole::Doctor));
            assert!(!owner);
        }
        _ => panic!("Expected Session response"),
    }

    assert!(matches!(outcome, AuthOutcome::Dashboard));
    Ok(())
}

#[tokio::test]
async fn test_no_profile_profile_build() -> Result<(), sqlx::Error> {
    let db = DatabaseDriver::new().await.unwrap();

    let (_, outcome) = determine_auth_outcome(
        &db,
        "2".into(),
        "Taha".into(),
        "tahachad@gmail.com".into(),
    )
    .await?;

    assert!(matches!(outcome, AuthOutcome::ProfileBuild));
    Ok(())
}