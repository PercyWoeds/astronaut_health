# Generates a concrete operational recommendation from the indicator and status.
# It does not replace medical judgement: red always points to the Flight Surgeon.
class RecommendationEngine
  # Actions per indicator and status. The text is written to be read quickly
  # on a cockpit panel, with action verbs and measurable steps.
  RECOMMENDATIONS = {
    "blood_pressure_systolic" => {
      "green" => "Maintain hydration and a resistance exercise routine. Re-measure at the next check.",
      "yellow" => "Rest 5 min, verify the cuff and re-measure. Record a second reading. Avoid caffeine and exertion.",
      "red" => "Rest immediately and re-measure in 5 min. If it persists > 140 or < 85 mmHg, report to the Flight Surgeon."
    },
    "blood_pressure_diastolic" => {
      "green" => "No action. Continue daily monitoring.",
      "yellow" => "Rest 5 min and repeat the measurement with the arm at heart level.",
      "red" => "Re-measure after 5 min of rest. If it persists >= 90 or < 50 mmHg, report to the Flight Surgeon."
    },
    "heart_rate" => {
      "green" => "No action. Maintain the cardiovascular and sleep routine.",
      "yellow" => "Assess stress, hydration and rest. Rest 5 min and re-measure.",
      "red" => "Stop activity, rest and re-measure. If it persists > 130 or < 40 bpm or symptoms appear, report to the Flight Surgeon."
    },
    "blood_glucose" => {
      "green" => "Maintain the meal pattern and record the trend.",
      "yellow" => "Review the last intake and activity. Re-measure in 30 min. If < 70 mg/dL, consume 15 g of carbohydrate.",
      "red" => "If < 54 mg/dL: treat hypoglycemia immediately and notify. If >= 250 mg/dL: hydrate and report to the Flight Surgeon."
    },
    "body_temperature" => {
      "green" => "No action. Continue monitoring.",
      "yellow" => "Hydration, rest and re-measure in 30 min. Watch for signs of infection.",
      "red" => "Activate the isolation protocol if there is fever. Report to the Flight Surgeon and monitor every 30 min."
    },
    "sleep_hours" => {
      "green" => "Maintain a sleep schedule and rest hygiene.",
      "yellow" => "Prioritize a 20-30 min nap and reduce light/stimulation before rest.",
      "red" => "Severe sleep deficit: suspend critical tasks, notify the team and schedule mandatory rest."
    },
    "mood_score" => {
      "green" => "Maintain a routine of family contact and recovery activities.",
      "yellow" => "Schedule a conversation with the team and a recovery activity. Record progress.",
      "red" => "Elevated psychosocial risk: report to the Flight Surgeon/psychologist and activate the support protocol."
    },
    "reaction_time" => {
      "green" => "Cognitive performance within range. Repeat the test at the next check.",
      "yellow" => "Cognitive fatigue detected. Rest is recommended (CIPHER / Spatial Cognition).",
      "red" => "Marked cognitive fatigue: suspend critical tasks, rest and repeat the test."
    },
    "meals_completed_percent" => {
      "green" => "Adequate intake. Maintain the mission meal plan.",
      "yellow" => "Inadequate Nutrition risk. Complete the remaining meals and record intake.",
      "red" => "Inadequate Nutrition risk. Review the plan with the team and consider supplementation."
    },
    "social_contact_minutes" => {
      "green" => "Adequate social contact. Maintain the crew interaction routine.",
      "yellow" => "Isolation risk (ARCHeR). Schedule contact with the crew and Earth.",
      "red" => "Critical isolation: activate the psychosocial protocol and contact Earth immediately."
    }
  }.freeze

  attr_reader :reading

  def initialize(reading)
    @reading = reading
  end

  # Returns { text:, urgency:, escalate: }.
  # urgency: :routine | :watch | :urgent
  def call
    if HealthEvaluator.new(reading).confirmed_extreme?
      return {
        text: HealthEvaluator::CONFIRMED_EXTREME_NOTE,
        urgency: "urgent",
        escalate: true
      }
    end

    if baseline_deviation?
      return {
        text: HealthEvaluator::BASELINE_PROTOCOL,
        urgency: "watch",
        escalate: false
      }
    end

    text = RECOMMENDATIONS.dig(reading.indicator_type, reading.status) ||
           "No specific recommendation. Record the value and consult the Flight Surgeon."

    {
      text: text,
      urgency: { "green" => "routine", "yellow" => "watch", "red" => "urgent" }.fetch(reading.status, "routine"),
      escalate: reading.status == "red"
    }
  end

  private

  def baseline_deviation?
    reading.status == "yellow" && HealthEvaluator.new(reading).baseline_deviation?
  end

  def self.for(reading)
    new(reading).call
  end
end
