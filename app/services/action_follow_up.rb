# Maneja el seguimiento de acciones completadas.
class ActionFollowUp
  def self.complete(alert_id)
    alert = Alert.find(alert_id)
    alert.resolve! if alert.status == "open"

    # Opcional: registrar en GroundReport para referencia
    GroundReport.create_for_alert(alert)

    { status: "completed", alert_id: alert.id }
  end

  def self.status(alert_id)
    alert = Alert.find(alert_id)
    alert.status
  end
end
