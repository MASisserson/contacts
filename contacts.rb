# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require 'bcrypt'
require 'yaml'

require_relative 'database_persistence'
require_relative 'user_obj'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'

  require 'pry'
end

# Check's that there is a contact with the given id.
def valid_contact_id?(contact_id)
  return if @storage.contact? contact_id

  session[:failure] = 'Sorry, we do not have such a contact on file.'
  redirect to '/contacts'
end

before do
  @storage = DatabasePersistence.new(logger)
end

# Redirects root page requests to '/contacts'
get '/' do
  redirect to '/contacts'
end

helpers do
  def sort_by(array, field)
    field = field.to_sym
    nil_values = array.select { |contact| contact[field].nil? }
    array.reject! { |contact| contact[field].nil? }
    array.sort_by! { |contact| contact[field] }
    array + nil_values.sort_by { |contact| contact[:name] }
  end
end

def find_path_to(dir)
  File.expand_path(dir, __dir__)
end

# Returns an array of User objects, containing all users
def all_users
  @storage.all_users
end

# Look for a user yml file based on a given username
def find_user(username)
  all_users.each do |obj|
    return obj if obj.username == username
  end

  false
end

# Validate login credentials
def valid_credentials?(saved_usr, username, saved_pwd, password)
  if saved_usr.username == username
    BCrypt::Password.new(saved_pwd) == password
  else
    false
  end
end

# Checks that the submitted username is valid.
def valid_username?(username)
  users = all_users

  users.each { |obj| return false if obj.username == username }

  return false if username.length > 50

  true
end

# Checks that the submitted password is valid
def valid_password?(password, password_confirm)
  password == password_confirm
end

# Creates a new user object with the given username and password
def create_user(username, password)
  User.new(username, BCrypt::Password.create(password).split('').join(''))
end

# Make sure given name is valid
def valid_name?(name)
  name.empty? ? session[:name_error] = 'Contact must have a name.' : true
end

# Check incoming phone number against current contacts
def phone_unique?(id, phone)
  contacts = @storage.contacts
  contacts.reject! { |contact| contact[:id] == id.to_s }
  !contacts.map { |contact| contact[:phone] }.include?(phone)
end

# Check incoming phone number format
def phone_formatted?(phone)
  phone =~ /^\([0-9]{3}\) [0-9]{3}-[0-9]{4}$/ ||
    phone =~ /^[0-9]{10}$/ ||
    phone =~ /^[0-9]{3}-[0-9]{3}-[0-9]{4}$/
end

# Make sure given phone number is valid
def valid_phone?(id, phone)
  if phone.empty?
    true
  elsif !phone_unique?(id, phone)
    session[:phone_error] = 'Another contact already has that phone number.'
  elsif !phone_formatted?(phone)
    session[:phone_error] = 'Please use the correct format: (###) ###-####.'
  else
    true
  end
end

# Checks that email is valid
def valid_email?(email)
  if email.empty?
    true
  elsif email.include?('@')
    true
  else
    session[:email_error] = 'Email must contain an "@".'
  end
end

# Return `true` if contact info is valid, `false` otherwise
def valid_info?(info)
  [valid_name?(info[:name]),
   valid_phone?(info[:id], info[:phone]),
   valid_email?(info[:email])].all? true
end

# Displays contacts from database
get '/contacts' do
  @sort_field = params[:sort_by] || 'name'
  @contacts = @storage.contacts

  erb :contacts
end

get '/contacts/new' do
  erb :new
end

get '/contacts/:contact_id/edit' do |contact_id|
  valid_contact_id?(contact_id)

  @contact_id = contact_id
  @contact = @storage.get_contact_info @contact_id

  erb :edit_contact
end

# Page for user account credential creation.
get '/users/new' do
  erb :new_user
end

# Creates a user account, and automatically logs it in.
post '/users/new' do
  username = params[:username]
  password = params[:password]
  pwd_confirm = params[:confirm]

  if !valid_username?(username)
    session[:failure] = 'Username already in use.'
    erb :new_user
  elsif !valid_password?(password, pwd_confirm)
    session[:failure] = 'Passwords do not match.'
    erb :new_user
  else
    new_user = create_user(username, password)
    @storage.add_user(new_user)

    session[:curr_usr] = username
    redirect to '/contacts'
  end
end

# Load login page
get '/users/login' do
  erb :login
end

# Submits and validates user sign in credentials
post '/users/login' do
  username = params[:username]
  password = params[:password]
  @user = find_user(username)

  if @user != false && valid_credentials?(@user, username,
                                          @user.password, password)

    session[:success] = 'Welcome!'
    session[:curr_usr] = username
    redirect to '/contacts'
  else
    status 422
    session[:failure] = 'Invalid credentials'
    erb :login, layout: :layout
  end
end

# Signs out a user
post '/users/signout' do
  session[:curr_usr] = nil
  session[:success] = 'You have been signed out.'
  redirect to '/contacts'
end

# Create a new contact
post '/contacts/new' do
  contact_info = { name: params[:name].strip,
                   phone: params[:phone].strip,
                   email: params[:email].strip,
                   category: params[:category].strip }

  if valid_info?(contact_info)
    @storage.add_contact(contact_info)

    session[:success] = "Added #{params[:name]} to contact list."
    redirect to '/contacts'
  else
    session[:failure] = 'The new contact could not be accepted.'
    redirect to '/contacts/new'
  end
end

# Update an existing contact
post '/contacts/:contact_id' do |contact_id|
  valid_contact_id?(contact_id)

  updated_info = { id: contact_id,
                   name: params[:name],
                   phone: params[:phone],
                   email: params[:email],
                   category: params[:category] }

  if valid_info?(updated_info)
    @storage.update_contact(updated_info)

    session[:success] = 'Contact edited.'
    redirect to '/contacts'
  else
    session[:failure] = 'The changes could not be accepted.'
    redirect to "/contacts/#{contact_id}/edit"
  end
end

# Delete a contact
post '/contacts/:contact_id/delete' do |contact_id|
  valid_contact_id?(contact_id)

  @storage.delete_contact(contact_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'Contact deleted.'
    redirect to '/contacts'
  end
end
