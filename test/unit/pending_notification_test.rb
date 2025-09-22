require File.expand_path('../../test_helper', __FILE__)

class PendingNotificationTest < ActiveSupport::TestCase
  test "should respond to its attributes" do
    notification = PendingNotification.new
    assert_respond_to notification, :issue_id
    assert_respond_to notification, :journal_id
    assert_respond_to notification, :user_id
  end
end
