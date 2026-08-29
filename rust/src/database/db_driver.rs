use uuid::Uuid;
use sqlx::{PgPool, postgres::PgPoolOptions};
use dotenvy::dotenv;
use std::env;

#[derive(Clone)]
pub struct DatabaseDriver {
   pub pool: PgPool,
}

impl DatabaseDriver {
    /// Creates a new driver and connects to the database using DATABASE_URL from .env
    pub async fn new() -> Result<Self, sqlx::Error> {
        dotenv().ok();
        let url = env::var("DATABASE_URL").expect("DATABASE_URL not set");
        let pool = PgPoolOptions::new()
            .max_connections(20)
            .connect(&url)
            .await?;
        Ok(Self { pool })
    }

        pub async fn set_rls(&self, conn: &mut sqlx::pool::PoolConnection<sqlx::Postgres>, user_id: Uuid) -> Result<(), sqlx::Error> {
        sqlx::query("SELECT set_config('myapp.user_id', $1, false)")
        .bind(user_id.to_string())
        .execute(&mut **conn)
        .await?;
        Ok(())

        }


 // TWO STARS?!
}

