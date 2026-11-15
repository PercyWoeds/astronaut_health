# Rate limiting por IP (ver app/middleware/rate_limiter.rb).
# Desactivado en test para evitar false-positivos; ajustable vía entorno.
# En producción se recomienda complementar con un límite en el proxy.
require Rails.root.join("app/middleware/rate_limiter")

Rails.application.config.middleware.use RateLimiter,
  general_limit: Integer(ENV.fetch("RATE_LIMIT_GENERAL", 300)),
  write_limit: Integer(ENV.fetch("RATE_LIMIT_WRITE", 60)),
  enabled: !Rails.env.test? && ENV["RATE_LIMIT_ENABLED"] != "false"
