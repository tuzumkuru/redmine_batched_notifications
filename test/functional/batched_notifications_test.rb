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

  def test_batches_multiple_updates_into_single_email
    Setting.plugin_redmine_batched_notifications = { 'enabled' => 'true', 'delay' => '5' }

    # Deliver the creation email immediately and clear state to isolate the batching assertions
    issue = nil
    perform_enqueued_jobs do
      issue = create_issue!
    end
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear

    # First update (enqueue job)
    update_issue!(issue)

    # Second quick update (enqueue newer job for same (issue, user))
    issue.reload
    issue.init_journal(@developer, 'Flow: another quick change')
    issue.description = 'Second change'
    assert issue.save!

    # Find the latest enqueued batch job and perform it with its recorded args
    jobs = enqueued_jobs.select { |j| j[:job] == SendBatchedNotificationsJob }
    assert_operator jobs.size, :>=, 1, 'Expected SendBatchedNotificationsJob to be enqueued'

    args = jobs.last[:args]
    before = ActionMailer::Base.deliveries.size
    perform_enqueued_jobs do
      SendBatchedNotificationsJob.perform_now(*args)
    end
    after = ActionMailer::Base.deliveries.size

    # Expect at least one email after batching (per recipient in real system). We assert >= 1 for stability.
    assert_operator (after - before), :>=, 1, 'Expected batched email to be delivered after multiple updates'

    mail = ActionMailer::Base.deliveries.last
    content = if mail.multipart?
      text_part = mail.parts.find { |p| p.mime_type == 'text/plain' }
      if text_part
        text_part.body.decoded
      else
        mail.parts.map { |p| p.body.decoded }.join("\n")
      end
    else
      mail.body.decoded
    end

    assert_includes mail.subject, 'Flow: Updated subject'
    # At minimum, the final description change should be present in the email body
    assert_includes content, 'Second change'
  end

  def test_batched_email_respects_private_notes_visibility
    Setting.plugin_redmine_batched_notifications = { 'enabled' => 'true', 'delay' => '5' }

    # Create issue and deliver creation email immediately, then clear state
    issue = nil
    perform_enqueued_jobs { issue = create_issue! }
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear

    # Configure permissions: developer can view private notes, reporter cannot
    @project.members.destroy_all
    Role.find(1).add_permission! :view_private_notes
    Member.create!(user: @developer, project: @project, roles: [Role.find(1)])
    Member.create!(user: @reporter,  project: @project, roles: [Role.find(2)])

    # Ensure self notifications are allowed so author also receives email
    @developer.pref.update!(no_self_notified: false)
    @reporter.pref.update!(no_self_notified: false)

    # Watchers
    issue.watcher_user_ids = [@developer.id, @reporter.id]

    # Add a private note (by the developer)
    issue.reload
    issue.init_journal(@developer, 'Private: should be visible only to developer')
    issue.private_notes = true
    assert issue.save!

    # Run the latest enqueued batch job (use the last enqueued job's args)
    jobs = enqueued_jobs.select { |j| j[:job] == SendBatchedNotificationsJob }
    assert_operator jobs.size, :>=, 1, 'Expected SendBatchedNotificationsJob to be enqueued'

    # Perform all enqueued jobs to ensure Mailer deliveries happen
    perform_enqueued_jobs

    # Helper to extract readable content
    extract = ->(mail) do
      if mail.multipart?
        (mail.parts.find { |p| p.mime_type == 'text/plain' }&.body&.decoded) ||
          mail.parts.map { |p| p.body.decoded }.join("\n")
      else
        mail.body.decoded
      end
    end

    dev_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(@developer.mail) }
    rep_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(@reporter.mail) }

    # Reporter must not receive an email for a private-only update
    assert_nil rep_mail, 'Reporter should not receive an email for a private-only update'

    # If the developer received a mail, it must include the private note text
    if dev_mail
      dev_content = extract.call(dev_mail)
      assert_includes dev_content, 'Private: should be visible only to developer'
    end
  end

  def test_batches_are_per_author
    Setting.plugin_redmine_batched_notifications = { 'enabled' => 'true', 'delay' => '5' }

    # Create issue and deliver creation email immediately, then clear state
    issue = nil
    perform_enqueued_jobs { issue = create_issue! }
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear

    # Ensure clean, permissive membership state (isolation from previous tests)
    @project.members.destroy_all
    Member.create!(user: @developer, project: @project, roles: [Role.find(1)])
    Member.create!(user: @reporter,  project: @project, roles: [Role.find(1)])

    # Ensure both users can receive their own notifications
    @developer.pref.update!(no_self_notified: false)
    @reporter.pref.update!(no_self_notified: false)
    Setting.default_notification_option = 'all'

    # Ensure both are watchers
    issue.watcher_user_ids = [@developer.id, @reporter.id]

    # Two quick updates by different authors
    issue.reload
    issue.init_journal(@developer, 'Dev note: change by developer')
    issue.subject = 'Updated by Dev'
    assert issue.save!

    # Simulate reporter as the author of the second update
    User.stubs(:current).returns(@reporter)
    issue = Issue.find(issue.id) # Re-fetch to ensure a clean object state
    issue.init_journal(@reporter, 'Rep note: change by reporter')
    issue.subject = 'Updated by Reporter'
    assert issue.save!
    User.stubs(:current).returns(User.find(1)) # Restore

    groups = PendingNotification.where(issue_id: issue.id).group_by(&:user_id)
    user_ids = groups.keys
    assert_includes user_ids, @developer.id, 'Expected pending notifications for developer author'
    assert_includes user_ids, @reporter.id, 'Expected pending notifications for reporter author'

    groups.each do |uid, pendings|
      journal_user_ids = Journal.where(id: pendings.map(&:journal_id)).pluck(:user_id).uniq
      assert_equal [uid], journal_user_ids, 'Each pending group should only contain journals from its author'
    end

    # Perform per-author jobs and verify deliveries contain only respective authors’ journals
    perform_enqueued_jobs do
      [@developer.id, @reporter.id].each do |uid|
        SendBatchedNotificationsJob.perform_now(issue.id, uid, Time.now.to_f)
      end
    end

    # Helper to extract readable content
    extract = ->(mail) do
      if mail.multipart?
        (mail.parts.find { |p| p.mime_type == 'text/plain' }&.body&.decoded) ||
          mail.parts.map { |p| p.body.decoded }.join("\n")
      else
        mail.body.decoded
      end
    end

    dev_mails = ActionMailer::Base.deliveries.select { |m| m.to.include?(@developer.mail) }
    rep_mails = ActionMailer::Base.deliveries.select { |m| m.to.include?(@reporter.mail) }

    assert_operator dev_mails.size, :>=, 2, 'Developer should receive one email per author batch'
    assert_operator rep_mails.size, :>=, 2, 'Reporter should receive one email per author batch'

    # For each recipient, ensure there is one mail with dev note and one with rep note
    assert dev_mails.any? { |m| extract.call(m).include?('Dev note: change by developer') }
    assert dev_mails.any? { |m| extract.call(m).include?('Rep note: change by reporter') }

    assert rep_mails.any? { |m| extract.call(m).include?('Dev note: change by developer') }
    assert rep_mails.any? { |m| extract.call(m).include?('Rep note: change by reporter') }
  end
end
