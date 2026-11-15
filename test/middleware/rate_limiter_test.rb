require "test_helper"

class RateLimiterTest < ActiveSupport::TestCase
  class EchoApp
    def call(_env)
      [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ]
    end
  end

  def env_for(method: "GET", ip: "10.0.0.1")
    { "REQUEST_METHOD" => method, "REMOTE_ADDR" => ip, "action_dispatch.remote_ip" => ip }
  end

  test "allows up to the general limit per window then returns 429" do
    limiter = RateLimiter.new(EchoApp.new, general_limit: 2, write_limit: 5, enabled: true)

    assert_equal 200, limiter.call(env_for)[0]
    assert_equal 200, limiter.call(env_for)[0]

    response = limiter.call(env_for)
    assert_equal 429, response[0]
    assert_equal "60", response[1]["Retry-After"]
  end

  test "write requests use their own bucket and limit" do
    limiter = RateLimiter.new(EchoApp.new, general_limit: 1, write_limit: 2, enabled: true)

    assert_equal 200, limiter.call(env_for(method: "POST"))[0]
    assert_equal 200, limiter.call(env_for(method: "POST"))[0]
    assert_equal 429, limiter.call(env_for(method: "POST"))[0]
    assert_equal 200, limiter.call(env_for)[0]
  end

  test "different IPs are tracked independently" do
    limiter = RateLimiter.new(EchoApp.new, general_limit: 1, write_limit: 1, enabled: true)

    assert_equal 200, limiter.call(env_for(ip: "1.1.1.1"))[0]
    assert_equal 429, limiter.call(env_for(ip: "1.1.1.1"))[0]
    assert_equal 200, limiter.call(env_for(ip: "2.2.2.2"))[0]
  end

  test "disabled middleware passes every request through" do
    limiter = RateLimiter.new(EchoApp.new, enabled: false)

    3.times { assert_equal 200, limiter.call(env_for)[0] }
  end
end
