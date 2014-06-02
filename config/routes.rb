Rails.application.routes.draw do

  get ':zip', to: 'pages#index'
  root 'pages#index'

end