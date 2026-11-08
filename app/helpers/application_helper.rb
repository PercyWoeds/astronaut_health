module ApplicationHelper
  STATUS_LABELS_ES = {
    "green" => "Normal",
    "yellow" => "Vigilar",
    "red" => "Crítico",
    "unknown" => "Sin datos"
  }.freeze

  def status_label_es(status)
    STATUS_LABELS_ES[status.to_s] || status.to_s
  end

  def relative_time_es(time)
    return "" unless time

    seconds = (Time.current - time).to_i
    return "Ahora" if seconds < 60

    minutes = seconds / 60
    return "Hace #{minutes} min" if minutes < 60

    hours = minutes / 60
    return "Hace #{hours} h" if hours < 24

    "Hace #{hours / 24} d"
  end
end
