use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::{fmt, EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

pub fn init_logging() -> WorkerGuard {
    let file_appender = tracing_appender::rolling::daily("logs", "veliclin.log");
    let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    let file_layer = fmt::layer()
    .with_writer(non_blocking)
    .with_ansi(false); // no color codes cluttering the log file

    let stdout_layer = fmt::layer()
    .with_writer(std::io::stdout);

    tracing_subscriber::registry()
    .with(filter)
    .with(file_layer)
    .with(stdout_layer)
    .init();

    guard
}