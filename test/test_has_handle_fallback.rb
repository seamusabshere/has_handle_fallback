require 'helper'

ActiveRecord::Schema.define(:version => 20090819143429) do
  create_table 'people', :force => true do |t|
    t.string :email
    t.string :handle
  end
  
  create_table 'cats', :force => true do |t|
    t.string :name
    t.string :moniker
  end
end

class Person < ActiveRecord::Base
  has_handle_fallback :email
end

class Cat < ActiveRecord::Base
  has_handle_fallback :name, :handle_column => 'moniker', :required => true
end

class TestHasHandleFallback < Test::Unit::TestCase
  def setup
    Person.delete_all
    Cat.delete_all
  end
  
  def test_has_handle
    ab = Person.new :email => 'a.b@example.com', :handle => 'AB'
    assert_equal 'AB', ab.handle
  end
  
  def test_has_fallback_handle_based_on_email
    ab = Person.new :email => 'a.b@example.com'
    assert_equal 'ab', ab.handle
  end
  
  def test_can_use_alternate_columns
    pierre = Cat.new :name => 'Pierre Bourdieu'
    assert_equal 'PierreBourdieu', pierre.handle
  end
  
  def test_can_in_fact_require_handle
    pierre = Cat.new :name => 'Pierre Bourdieu'
    assert_equal false, pierre.valid?
  end
  
  def test_has_validations
    assert_equal true, Person.new(:email => 'pierre.bourdieu@example.com', :handle => 'Pierre-Bourdieu_99').valid?
    assert_equal false, Person.new(:email => 'pierre.bourdieu@example.com', :handle => 'Pierre:Bourdieu_99').valid?
  end
  
  def test_validates_uniqueness_ignoring_case
    Person.create!(:email => 'pierre.bourdieu@example.com', :handle => 'Pierre-Bourdieu_99')
    b = Person.create(:email => 'pierre.bourdieu@example.com', :handle => 'PIERRE-BOURDIEU_99')
    if ActiveRecord::VERSION::MAJOR == 2
      assert_equal "isn't unique", b.errors.on(:handle)
    else
      assert_equal "isn't unique", b.errors[:handle].first
    end
  end
  
  def test_can_have_nil_handle
    assert_equal true, Person.new(:email => 'pierre.bourdieu@example.com', :handle => nil).valid?
  end
  
  def test_cannot_have_blank_handle
    assert_equal false, Person.new(:email => 'pierre.bourdieu@example.com', :handle => '          ').valid?
  end
  
  def test_cannot_have_indecent_handle
    assert_equal false, Person.new(:email => 'pierre.bourdieu@example.com', :handle => 'scuntshorpe').valid?
  end
  
  def test_is_careful_with_things_that_look_like_emails
    assert_equal 'pierrebourdieu', Person.new(:email => 'pierre.bourdieu@example.com').handle
  end
  
  def test_only_uses_handle_as_param_when_not_changed_from_value_in_database
    pierre = Person.new(:email => 'pierre.bourdieu@example.com')
    
    # not saved, so to_param is just blank
    assert_equal '', pierre.to_param
    assert_equal nil, Person[pierre.to_param]
    
    # no handle set, so to_param is integer primary key
    pierre.save!
    assert_equal pierre.id.to_s, pierre.to_param
    assert_equal pierre, Person[pierre.to_param]
    
    # handle is set, but not saved, so STILL use integer primary key
    pierre.handle = 'pierrebourdieu'
    assert_equal pierre.id.to_s, pierre.to_param
    assert_equal pierre, Person[pierre.to_param]
    
    # now handle is saved, so we can use it as the param
    pierre.save!
    assert_equal 'pierrebourdieu', pierre.to_param
    assert_equal pierre, Person[pierre.to_param]
    
    # handle was changed, so let's use the integer primary key until it's saved again
    pierre.handle = ''
    assert_equal pierre.id.to_s, pierre.to_param
    assert_equal pierre, Person[pierre.to_param]
  end
  
  def test_finds_by_id_or_handle_ignoring_case
    handle = 'Pierre-Bourdieu_99'
    a = Person.create!(:email => 'pierre.bourdieu@example.com', :handle => handle.upcase)
    assert_equal a, Person[handle.downcase]
  end
end
