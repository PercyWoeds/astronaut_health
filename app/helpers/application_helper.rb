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

  # Estilo común de la barra de acciones rápidas (Mission Control).
  def quick_action_button_classes
    "rounded-xl border border-slate-700 bg-gray-800 px-4 py-2.5 font-mono text-sm font-semibold " \
      "text-slate-200 transition hover:border-cyan-500 hover:text-white"
  end
end
