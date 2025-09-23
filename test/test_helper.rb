# Load the Redmine helper
# This loads the test framework and our Redmine test environment
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')
require 'shoulda/context'
require 'mocha/minitest'

# Set the fixture path for this plugin
ActiveSupport::TestCase.fixture_paths << File.dirname(__FILE__) + "/fixtures/"

# Add the plugin's lib directory to the load path
$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

# Use the test adapter for Active Job
ActiveJob::Base.queue_adapter = :test

# Force the mailer to use the test delivery method
ActionMailer::Base.delivery_method = :test

