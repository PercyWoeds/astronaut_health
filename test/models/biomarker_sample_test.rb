require "test_helper"

class BiomarkerSampleTest < ActiveSupport::TestCase
  def astronaut
    @astronaut ||= begin
      mission = Mission.create!(name: "Biomarker Test", code: "BT-#{SecureRandom.hex(4)}")
      Astronaut.create!(name: "Biomarker #{SecureRandom.hex(2)}", mission: mission)
    end
  end

  test "notes longer than 1000 characters are rejected" do
    sample = BiomarkerSample.new(astronaut: astronaut, sample_type: "blood", collected_at: Time.current, notes: "a" * 1001)

    assert_not sample.valid?
    assert_includes sample.errors[:notes], "is too long (maximum is 1000 characters)"
  end

  test "notes up to 1000 characters are accepted" do
    sample = BiomarkerSample.new(astronaut: astronaut, sample_type: "blood", collected_at: Time.current, notes: "a" * 1000)

    assert sample.valid?
  end
end
