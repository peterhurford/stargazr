Rails.application.routes.draw do

  get '/diagnostic', to: 'pages#diagnostic'
  post '/diagnostic', to: 'pages#diagnostic'
  post '/', to: 'pages#index'
  get ':zip/diagnostic', to: 'pages#diagnostic'
  get ':zip', to: 'pages#index'
  
  root 'pages#index'

end