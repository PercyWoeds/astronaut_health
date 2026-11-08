Rails.application.routes.draw do
  # Verificación de salud de la propia app (no confundir con salud del astronauta).
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  # Captura y consulta de mediciones (responde HTML y JSON).
  resources :health_readings, only: [ :new, :create, :index ]

  # Endpoints consumidos por Three.js y Chart.js.
  namespace :api do
    resource :health_status, only: :show, controller: "health_status"
    # Panel de los 5 peligros del NASA HRP (se refresca en vivo).
    resource :hrp_risks, only: :show, controller: "hrp_risks"
    resources :health_readings, only: [ :index ] do
      collection do
        get :chart_data
      end
    end
  end
end
