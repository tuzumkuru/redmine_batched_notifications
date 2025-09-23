require File.expand_path('../../test_helper', __FILE__)
require 'mocha/minitest'
require 'active_job/test_helper'

# End-to-end flow test verifying mail behavior with the plugin
# disabled vs enabled. This serves as a simple, reliable baseline.
class BatchedNotificationsTest < ActiveSupport::TestCase
  # Disable transactional tests so after_commit callbacks (which trigger
  # Journal#send_notification) actually fire during the test run.
  self.use_transactional_tests = false

  include ActiveJob::TestHelper

  fixtures :projects, :trackers, :issue_statuses, :issues, :journals,
           :enumerations, :users, :roles, :members, :member_roles,
           :projects_trackers, :enabled_modules, :workflows, :watchers

  def setup
    Setting.default_language = 'en'
    Setting.host_name = 'example.test'
    Setting.protocol = 'http'

    # Ensure all notification events are on to satisfy Journal#notify?
    Setting.notified_events = Redmine::Notifiable.all.collect(&:name)

    # Use a stable current user (admin)
    User.stubs(:current).returns(User.find(1))

    @project = Project.find(1)
    @developer = User.find(2) # jsmith
    @reporter  = User.find(3) # dlopper

    # Make sure both users will receive notifications
    @developer.update_column(:mail_notification, 'all')
    @reporter.update_column(:mail_notification, 'all')

    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  def create_issue!
    Issue.create!(
      project_id: @project.id,
      tracker_id: 1,
      author_id: @developer.id,
      assigned_to_id: @developer.id,
      status_id: 1,
      priority: IssuePriority.first,
      subject: 'Flow: New issue',
      watcher_user_ids: [@developer.id, @reporter.id]
    )
  end

  def update_issue!(issue)
    issue.reload
    issue.init_journal(@developer, 'Flow: updated description')
    issue.subject = 'Flow: Updated subject'
    assert issue.save!
    issue
  end

  def test_mail_flow_disabled_then_enabled
    # 1) Plugin disabled -> creation sends immediately, update sends immediately
    Setting.plugin_redmine_batched_notifications = { 'enabled' => 'false' }

    perform_enqueued_jobs do
      before = ActionMailer::Base.deliveries.size
      issue = create_issue!
      mid = ActionMailer::Base.deliveries.size
      assert_operator (mid - before), :>=, 1, 'Expected at least 1 email on issue creation when plugin disabled'

      update_issue!(issue)
      after = ActionMailer::Base.deliveries.size
      assert_operator (after - mid), :>=, 1, 'Expected at least 1 email on issue update when plugin disabled'
    end

    # 2) Plugin enabled -> creation sends immediately, update enqueues (no immediate mail)
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs

    Setting.plugin_redmine_batched_notifications = { 'enabled' => 'true', 'delay' => '5' }

    # Creation still sends now (issue_added is not batched by our plugin)
    issue2 = nil
    perform_enqueued_jobs do
      before2 = ActionMailer::Base.deliveries.size
      issue2 = create_issue!
      after2 = ActionMailer::Base.deliveries.size
      assert_operator (after2 - before2), :>=, 1, 'Expected at least 1 email on issue creation when plugin enabled'
    end

    # Update: should enqueue a batched job, no immediate emails (do NOT perform enqueued jobs here)
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      assert_enqueued_jobs 1 do
        update_issue!(issue2)
      end
    end
  end
end
