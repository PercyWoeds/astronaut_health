class DemoController < ApplicationController
  # Fuera de development/test el reset requiere el token compartido; con el
  # token correcto la protección CSRF es redundante.
  skip_forgery_protection if: -> { Rails.env.development? || Rails.env.test? || demo_reset_token_valid? }

  # Recrea los datos de demo ejecutando db/seeds.rb (borra y regenera).
  def reset
    unless demo_reset_allowed?
      head :forbidden
      return
    end

    Rails.application.load_seed
    redirect_back fallback_location: root_path, notice: "Demo data recreated from seeds."
  end

  private

  def demo_reset_allowed?
    return true if Rails.env.development? || Rails.env.test?

    demo_reset_token_valid?
  end

  def demo_reset_token_valid?
    token = ENV["DEMO_RESET_TOKEN"].to_s
    token.present? && ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)
  end
end
