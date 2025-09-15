class SendBatchedNotificationsJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, scheduled_at_timestamp)
    scheduled_at = Time.at(scheduled_at_timestamp)
    expected_run_time = Rails.cache.read("notification_time_for_issue_#{issue_id}")

    # If the expected run time is later than this job's scheduled time,
    # it means a newer job has been enqueued. So, this one should do nothing.
    # We add a small grace period (e.g., 1 second) to account for minor timing discrepancies.
    return if expected_run_time.present? && expected_run_time.to_i > scheduled_at.to_i

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
      Rails.cache.delete("notification_time_for_issue_#{issue_id}")
    end
  end
end