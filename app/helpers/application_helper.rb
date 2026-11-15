module ApplicationHelper
  # Las vistas siguen llamando a status_label_es / relative_time_es (no se
  # renombran), pero los textos visibles se devuelven en inglés.
  STATUS_LABELS = HealthEvaluator::ALERT_LEVELS
  STATUS_ICONS = { "green" => "✓", "yellow" => "!", "red" => "▲", "unknown" => "?" }.freeze

  def status_label_es(status)
    STATUS_LABELS[status.to_s] || status.to_s
  end

  def status_icon(status)
    STATUS_ICONS.fetch(status.to_s, "?")
  end

  # A reading only becomes a "possible emergency" when the user explicitly
  # confirmed an extreme value. Threshold crossings use the normal alert level.
  def reading_alert_label(reading)
    confirmed = reading.respond_to?(:confirmed_extreme?) && reading.confirmed_extreme?
    HealthEvaluator.alert_label(reading.status, confirmed_extreme: confirmed)
  end

  def reference_scope_label(indicator_type)
    HealthEvaluator.reference_scope_for(indicator_type)
  end

  def relative_time_es(time)
    return "" unless time

    seconds = (Time.current - time).to_i
    return "Now" if seconds < 60

    minutes = seconds / 60
    return "#{minutes} min ago" if minutes < 60

    hours = minutes / 60
    return "#{hours} h ago" if hours < 24

    "#{hours / 24} d ago"
  end

  # Estilo común de la barra de acciones rápidas (Mission Control).
  def quick_action_button_classes
    "rounded-xl border border-slate-700 bg-gray-800 px-4 py-2.5 font-mono text-sm font-semibold " \
      "text-slate-200 transition hover:border-cyan-500 hover:text-white"
  end
end
