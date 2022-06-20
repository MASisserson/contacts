# frozen_string_literal: true

require 'pg'

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
  def contacts
    sql = 'SELECT * FROM contacts'
    result = query(sql)

    result.map { |tuple| format_contact_info(tuple) }
  end

  # Query database for 1 contact's info, based on their id
  def get_contact_info(contact_id)
    sql = 'SELECT * FROM contacts WHERE id = $1'
    contact_result = query(sql, contact_id)

    format_contact_info(contact_result.first)
  end

  def update_contact(c)
    sql = <<~SQL
      UPDATE contacts
        SET "name" = $1, phone = $2, email = $3, category = $4
        WHERE id = $5
    SQL
    phone = format_phone_for_database(c[:phone])
    set_nil_values!(c)

    query(sql, c[:name], phone, c[:email], c[:category], c[:id])
  end

  def add_contact(c)
    sql = <<~SQL
      INSERT INTO contacts ("name", phone, email, category)
        VALUES ($1, $2, $3, $4)
    SQL
    phone = format_phone_for_database(c[:phone])
    set_nil_values!(c)

    query(sql, c[:name], phone, c[:email], c[:category])
  end

  def delete_contact(id)
    sql = 'DELETE FROM contacts WHERE id = $1'
    query(sql, id)
  end

  def contact?(id)
    sql = 'SELECT 1 WHERE EXISTS (SELECT "name" FROM contacts WHERE id = $1)'
    result = query(sql, id).values.first == ['1']
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
    { id: contact_info['id'],
      name: contact_info['name'],
      phone: format_phone_for_user(contact_info['phone']),
      email: contact_info['email'],
      category: contact_info['category'] }
  end

  def set_nil_values!(contact_info)
    contact_info.each_key do |key|
      contact_info[key] = nil if contact_info[key].empty?
    end
  end
end
