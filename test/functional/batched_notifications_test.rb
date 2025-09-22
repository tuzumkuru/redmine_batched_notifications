require File.expand_path('../../test_helper', __FILE__)

class BatchedNotificationsTest < Redmine::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :users, :email_addresses, :roles, :members, :member_roles

  def setup
    # This setup runs before each test
    ActionMailer::Base.deliveries.clear
    Setting.plain_text_mail = '1' # Use text mail for easier inspection
    # Ensure all notifications are on for the test
    Setting.notified_events = Redmine::Notifiable.all.collect(&:name)
  end

  test "creating a new issue should send an email immediately" do
    # Log in as a user who can create issues
    log_user('jsmith', 'jsmith') # User 2, a manager

    # Set a different user to be the watcher
    watcher_user = User.find(3) # dlopper, a developer
    watcher_user.update!(mail_notification: 'all')

    # Create the issue by posting to the controller
    post '/projects/1/issues', params: {
      issue: {
        tracker_id: 1,
        subject: 'New issue from integration test',
        description: 'This is the description.',
        watcher_user_ids: [watcher_user.id]
      }
    }

    # The request should succeed and redirect to the new issue
    assert_response :redirect
    new_issue = Issue.last
    assert_redirected_to "/issues/#{new_issue.id}"

    # Manually assert that an email was sent
    assert_equal 2, ActionMailer::Base.deliveries.size, "Expected 2 emails to be sent, but found #{ActionMailer::Base.deliveries.size}"

    # Verify the email details
    recipient_mails = ActionMailer::Base.deliveries.map { |d| d.to }.flatten
    assert_includes recipient_mails, watcher_user.mail
  end
end
