# Rate limiting ligero por IP (fixed window de 60 segundos).
# Sin dependencias: estado en memoria, suficiente para el demo. En producción
# se recomienda además un límite en el proxy (Render/nginx) o rack-attack.
class RateLimiter
  WINDOW = 60

  def initialize(app, general_limit: 300, write_limit: 60, enabled: true)
    @app = app
    @general_limit = general_limit
    @write_limit = write_limit
    @enabled = enabled
    @store = Hash.new { |h, k| h[k] = { window: 0, count: 0 } }
    @mutex = Mutex.new
  end

  def call(env)
    return @app.call(env) unless @enabled

    key = bucket_key(env)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i
    limit = write_method?(env) ? @write_limit : @general_limit

    allowed = @mutex.synchronize do
      slot = @store[key]
      slot = @store[key] = { window: now, count: 0 } if now - slot[:window] >= WINDOW
      slot[:count] += 1
      slot[:count] <= limit
    end

    return too_many(limit) unless allowed

    @app.call(env)
  end

  private

  def write_method?(env)
    %w[POST PUT PATCH DELETE].include?(env["REQUEST_METHOD"])
  end

  def bucket_key(env)
    ip = env["action_dispatch.remote_ip"] || env["REMOTE_ADDR"] || "unknown"
    "#{write_method?(env) ? "write" : "read"}:#{ip}"
  end

  def too_many(limit)
    body = "Rate limit exceeded (#{limit} requests per minute). Retry after #{WINDOW} seconds."
    [ 429, { "Content-Type" => "text/plain", "Retry-After" => WINDOW.to_s, "Content-Length" => body.bytesize.to_s }, [ body ] ]
  end
end
