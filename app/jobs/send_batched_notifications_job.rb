class SendBatchedNotificationsJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id)
    lock_key = "batched_notifications_job_#{issue_id}"
    return if Rails.cache.read(lock_key) # Skip if already running
    Rails.cache.write(lock_key, true, expires_in: 10.minutes) # Lock for 10 min

    begin
      pending_notifications = PendingNotification.where(issue_id: issue_id)
      return if pending_notifications.empty?

      issue = Issue.find(issue_id)
      journals = Journal.where(id: pending_notifications.pluck(:journal_id))

      # Group journals by author (journal.user)
      author_journals = Hash.new { |h, k| h[k] = [] }
      journals.each do |journal|
        author_journals[journal.user] << journal.id
      end

      # For each author, send batched emails to their notified users
      author_journals.each do |author, journal_ids|
        all_notified_users = Set.new
        journals.where(id: journal_ids).each do |journal|
          all_notified_users.merge(journal.notified_users)
        end

        all_notified_users.each do |user|
          Mailer.deliver_batched_issue_edit(user, issue, journal_ids, author)
        end
      end

    pending_notifications.destroy_all
    ensure
      Rails.cache.delete(lock_key) # Release lock
    end
  end

  private

  def should_notify_user?(user, issue, journals)
    return false if user.mail.blank? || user.mail_notification == 'none'

    case user.mail_notification
    when 'all'
      true
    when 'selected'
      issue.watchers.include?(user) || issue.assigned_to == user || issue.author == user || journals.any? { |j| j.user == user }
    when 'only_my_events'
      journals.any? { |j| j.user == user }
    when 'only_assigned'
      issue.assigned_to == user
    when 'only_owner'
      issue.author == user
    else
      false
    end
  end
end

