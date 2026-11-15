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

  # Deploy info: prioriza variables de entorno (Render, CI), y en local cae
  # de vuelta a los metadatos de .git. En producción el contenedor no tiene .git.
  def deploy_revision
    @deploy_revision ||= ENV["REVISION"].presence || ENV["SOURCE_VERSION"].presence ||
      ENV["RENDER_GIT_COMMIT"].presence || git_revision
  end

  def deployed_at
    @deployed_at ||= begin
      raw = ENV["DEPLOYED_AT"].presence || git_committed_at
      Time.zone.parse(raw) if raw.present?
    rescue ArgumentError
      nil
    end
  end

  # El reset de demo está disponible en development/test y en cualquier otro
  # entorno solo si se configuró DEMO_RESET_TOKEN.
  def demo_reset_enabled?
    Rails.env.development? || Rails.env.test? || ENV["DEMO_RESET_TOKEN"].present?
  end

  def demo_reset_token_required?
    !Rails.env.development? && !Rails.env.test?
  end

  private

  def git_revision
    head = Rails.root.join(".git/HEAD")
    return nil unless head.exist?

    ref = head.read.strip
    return ref unless ref.start_with?("ref: ")

    ref_path = Rails.root.join(".git", ref.delete_prefix("ref: ").strip)
    ref_path.read.strip if ref_path.exist?
  rescue StandardError
    nil
  end

  def git_committed_at
    log_file = Rails.root.join(".git/logs/HEAD")
    return nil unless log_file.exist?

    line = log_file.read.split("\n").last
    return nil if line.blank?

    Time.zone.at(line.split[2].to_i).iso8601
  rescue StandardError
    nil
  end
end
