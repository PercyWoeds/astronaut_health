require "test_helper"

class HealthSnapshotTest < ActiveSupport::TestCase
  setup do
    mission = Mission.create!(name: "Snapshot Test", code: "SN-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Snapshot Astronaut", mission: mission)

    %w[head chest abdomen limbs].each do |name|
      BodyZone.create!(
        name: name,
        description: "Zona #{name}",
        related_indicators: [ "body_temperature" ]
      )
    end
  end

  test "virus reactivation suspected pinta todas las zonas de rojo" do
    @astronaut.research_assessments.create!(
      assessed_on: Date.current,
      virus_reactivation_suspected: true,
      vision_test_performed: true
    )

    snapshot = HealthSnapshot.new(@astronaut).as_json

    assert_equal "red", snapshot[:overall_status]
    assert snapshot[:zones].all? { |zone| zone[:status] == "red" }
    assert snapshot[:zones].any? { |zone| zone[:name] == "immune" && zone[:status] == "red" }
  end

  test "síntomas de visión y erupción pintan cabeza e immune de rojo" do
    @astronaut.symptom_checks.create!(
      checked_on: Date.current,
      rash_or_hives: true,
      vision_changes: true,
      dizziness_nausea: false
    )

    snapshot = HealthSnapshot.new(@astronaut).as_json
    head = snapshot[:zones].find { |zone| zone[:name] == "head" }
    immune = snapshot[:zones].find { |zone| zone[:name] == "immune" }

    assert_equal "red", head[:status]
    assert_equal "red", immune[:status]
    assert_equal "red", snapshot[:overall_status]
  end

  test "egress pendiente aparece en la zona de huesos" do
    @astronaut.pre_eva_checks.create!(
      o2_ok: true,
      pressure_ok: true,
      fatigue_ok: true,
      egress_fitness_completed: false
    )

    snapshot = HealthSnapshot.new(@astronaut).as_json
    limbs = snapshot[:zones].find { |zone| zone[:name] == "limbs" }

    assert_equal "yellow", limbs[:status]
    assert limbs[:indicators].any? { |indicator| indicator[:type] == "egress_fitness_completed" }
  end
end
