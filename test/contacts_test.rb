ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use!
require 'rack/test'
require 'fileutils'

require_relative '../contacts'

class ContactsTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    puts `psql contacts_test < schema.sql`
  end

  def test_root_page_and_contact_list
    get '/'
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Contacts'
  end

  def test_contact_editing_form
    get '/contacts/1/edit'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Hank Hill'
  end

  def test_edit_contact_success
    post '/contacts/1', { name: 'Mandy', phone: '(012) 345-6789', email: 'king@hill.com', category: 'Friend' }
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Mandy'
  end

  def test_edit_contact_failure
    post '/contacts/1', { name: 'Mandy', phone: '(123) 456-7890',
                          email: 'king@hill.com', category: 'Friend' }

    get last_response['Location']
    assert_includes last_response.body,
                    'Another contact already has that phone number.'
  end

  def test_new_contact_form
    get '/contacts/new'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body,
                    'Name'
  end

  def teardown
    db = PG.connect(dbname: 'contacts_test')
    db.exec 'DROP TABLE contacts;'
  end
end
