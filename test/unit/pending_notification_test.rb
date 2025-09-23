require File.expand_path('../../test_helper', __FILE__)

class PendingNotificationTest < ActiveSupport::TestCase
  fixtures :issues, :journals, :users

  test "should create a pending notification" do
    notification = PendingNotification.new(
      issue_id: 1,
      journal_id: 1,
      user_id: 1
    )
    assert notification.save
    assert_equal 1, notification.issue_id
    assert_equal 1, notification.journal_id
    assert_equal 1, notification.user_id
  end

  test "should respond to its attributes" do
    notification = PendingNotification.new
    assert_respond_to notification, :issue_id
    assert_respond_to notification, :journal_id
    assert_respond_to notification, :user_id
  end

  test "should belong to an issue" do
    notification = PendingNotification.new(issue: issues(:issues_001))
    assert_equal issues(:issues_001), notification.issue
  end
end
