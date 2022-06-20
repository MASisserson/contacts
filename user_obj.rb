# frozen_string_literal: true

require 'bcrypt'

# User class for tracking user data
class User
  include BCrypt

  attr_reader :username, :password

  def initialize(username, password)
    @username = username
    @password = password
  end
end
