require 'simplecov'
SimpleCov.start
require 'bahai_date'

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
