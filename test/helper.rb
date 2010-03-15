require 'rubygems'
require 'test/unit'
require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'has_handle_fallback'

class Test::Unit::TestCase
end

ActiveRecord::Base.establish_connection(
  'adapter' => 'sqlite3',
  'database' => 'test/test.sqlite3'
)
