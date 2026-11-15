require "test_helper"

class CommDelayTest < ActiveSupport::TestCase
  def astronaut(destination)
    Astronaut.new(name: "Test", mission: Mission.new, destination: destination)
  end

  test "Luna usa aproximadamente 1.3 s por sentido" do
    assert_in_delta 1.3, CommDelay.seconds_for(astronaut("moon")), 0.001
    assert_match "1.3 s", CommDelay.text_for(astronaut("moon"))
  end

  test "Marte usa el ejemplo medido de 11 min 22 s como valor de demo" do
    with_env("MARS_ONE_WAY_DELAY_MINUTES" => nil) do
      assert_in_delta 11.38 * 60, CommDelay.seconds_for(astronaut("mars")), 0.01
      text = CommDelay.text_for(astronaut("mars"))
      assert_match "11 min", text
      assert_match "demo value", text
      assert_match "few minutes to more than 20 min", text
    end
  end

  test "el valor de Marte es configurable y se limita al rango documentado" do
    with_env("MARS_ONE_WAY_DELAY_MINUTES" => "25") do
      assert_in_delta 25 * 60, CommDelay.seconds_for(astronaut("mars")), 0.01
    end

    with_env("MARS_ONE_WAY_DELAY_MINUTES" => "999") do
      assert_in_delta CommDelay::MARS_MAX_MINUTES * 60, CommDelay.seconds_for(astronaut("mars")), 0.01
    end
  end

  test "la ISS es un enlace de baja latencia simulado" do
    assert_match "simulated", CommDelay.text_for(astronaut("iss"))
  end

  test "el retraso es informativo y no cambia el estado" do
    payload = CommDelay.environments.fetch("mars")

    assert payload[:protocol].include?("does not change the health status")
    refute_includes payload.keys, :status
  end

  private

  def with_env(values)
    old = values.transform_values { |_| ENV["MARS_ONE_WAY_DELAY_MINUTES"] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    old.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
