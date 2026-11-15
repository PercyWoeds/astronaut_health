require "test_helper"

class DemoResetTest < ActionDispatch::IntegrationTest
  test "POST reset recrea los datos de demo" do
    post demo_reset_path

    assert_response :redirect
    assert_equal 2, Mission.count
  end

  test "GET reset no está permitido" do
    get demo_reset_path

    assert_response :missing
  end
end
