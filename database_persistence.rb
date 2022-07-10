# frozen_string_literal: true

require 'pg'

require_relative 'user_obj'

# Handles communication with the database
class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          elsif ENV['RACK_ENV'] == 'test'
            PG.connect(dbname: 'contacts_test')
          else
            PG.connect(dbname: 'contacts')
          end
    @logger = logger
  end

  # Query database for contact list, return as an array of hashes
  def contacts(username)
    sql = <<~SQL
      SELECT contacts.* FROM contacts
        JOIN users ON users.id = contacts.user_id
        WHERE users.username = $1
    SQL

    result = query(sql, username)

    result.map { |tuple| format_contact_info(tuple) }
  end

  # Query database for 1 contact's info, based on their id
  def get_contact_info(contact_id)
    sql = 'SELECT * FROM contacts WHERE id = $1'
    contact_result = query(sql, swap_id_type(contact_id))

    format_contact_info(contact_result.first)
  end

  # Takes a contact's new info and updates it in the database
  def update_contact(contact)
    sql = <<~SQL
      UPDATE contacts
        SET "name" = $1, phone = $2, email = $3, category = $4
        WHERE id = $5
    SQL
    phone = format_phone_for_database(contact[:phone])
    convert_empty_string_to_nil!(contact)

    query(sql, contact[:name], phone, contact[:email],
          contact[:category], swap_id_type(contact[:id]))
  end

  # Adds contact info into the contacts and contact_ids tables
  def add_contact(contact, user)
    insert_to_contacts(contact, user)
    insert_to_contact_ids(contact[:name], user)
  end

  def delete_contact(id)
    sql = 'DELETE FROM contacts WHERE id = $1'

    query(sql, swap_id_type(id))
  end

  # Returns true if the selected contact exists for the selected user.
  def contact?(id, user)
    sql = <<~SQL
      SELECT users.username FROM users
        JOIN contacts ON contacts.user_id = users.id
        WHERE contacts.id = $1 AND "username" = $2
    SQL

    result = query(sql, swap_id_type(id), user)
    result.values.first == [user]
  end

  # Returns an array of User objects
  def all_users
    sql = 'SELECT username, "password" FROM users'
    query(sql).map do |user_info|
      User.new(user_info['username'], user_info['password'])
    end
  end

  # Inserts a new user into the user table
  def add_user(new_user)
    sql = 'INSERT INTO users (username, "password") VALUES ($1, $2)'
    query(sql, new_user.username, new_user.password)
  end

  private

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params statement, params
  end

  def format_phone_for_database(user_format)
    return if user_format.nil? || user_format.empty?

    user_format.delete '^[0-9]'
  end

  def format_phone_for_user(just_digits)
    return if just_digits.nil? || just_digits.empty?

    n = just_digits.chars
    "(#{n[0..2].join}) #{n[3..5].join}-#{n[6..9].join}"
  end

  def format_contact_info(contact_info)
    { id: swap_id_type(contact_info['id']),
      name: contact_info['name'],
      phone: format_phone_for_user(contact_info['phone']),
      email: contact_info['email'],
      category: contact_info['category'] }
  end

  def convert_empty_string_to_nil!(contact_info)
    contact_info.each_key do |key|
      contact_info[key] = nil if contact_info[key].empty?
    end
  end

  def insert_to_contacts(contact, user)
    sql = <<~SQL
      INSERT INTO contacts ("name", phone, email, category, "user_id")
        VALUES ($1, $2, $3, $4, (SELECT id FROM users WHERE username = $5))
    SQL
    phone = format_phone_for_database(contact[:phone])
    convert_empty_string_to_nil!(contact)

    query(sql, contact[:name], phone, contact[:email], contact[:category], user)
  end

  def insert_to_contact_ids(contact_name, username)
    sql = <<~SQL
      INSERT INTO contact_ids (uuid, contact_id)
        VALUES ($1, (
          SELECT contacts.id FROM contacts
            JOIN users ON users.id = contacts.user_id
            WHERE users.username = $2 AND contacts.name = $3
            ORDER BY contacts.id DESC LIMIT 1
        ))
    SQL

    query(sql, generate_uuid, username, contact_name)
  end

  def generate_uuid
    SecureRandom.hex(10)
  end

  # Takes a string id, and checks that it is a valid hexadecimal
  def uuid?(id_string)
    !id_string[/\H/]
  end

  # Takes a string id, and checks that it is a valid integer
  def id?(id_string)
    !id_string[/\D/]
  end

  def get_uuid(id)
    sql = 'SELECT "uuid" FROM contact_ids WHERE contact_id = $1'
    result = query(sql, id)
    result.values.first.first
  end

  def get_id(uuid)
    sql = 'SELECT contact_id FROM contact_ids WHERE "uuid" = $1'
    result = query(sql, uuid)
    result.values.first.first
  end

  # Takes a contact id, either as a UUID or an integer, and returns its opposite on the contact_ids table.
  def swap_id_type(contact_id)
    if id?(contact_id)
      get_uuid(contact_id)
    elsif uuid?(contact_id)
      get_id(contact_id)
    end
  end
end
