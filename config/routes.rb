Rails.application.routes.draw do

  get ':zip', to: 'pages#index'
  post '/', to: 'pages#index'
  root 'pages#index'

end