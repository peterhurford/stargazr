Rails.application.routes.draw do

  get 'pages/index'
  get ':Zip', to: 'pages#index'
  get 'pages/weather', to: 'pages#index'
  post 'pages/weather', to: 'pages#index'

  root 'pages#index'

end