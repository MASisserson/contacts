# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'

# require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'

  require 'pry'
end

# Redirects root page requests to '/contacts'
get '/' do
  redirect to '/contacts'
end

before do
  @storage = DatabasePersistence.new
end

# Displays contacts from database
get '/contacts' do
  @contact_list = @storage.contacts
end
