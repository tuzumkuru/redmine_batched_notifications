class SendBatchedNotificationsJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, scheduled_at_timestamp)
    scheduled_at = Time.at(scheduled_at_timestamp)
    expected_run_time = Rails.cache.read("notification_time_for_issue_#{issue_id}")

    # If the expected run time is later than this job's scheduled time,
    # it means a newer job has been enqueued. So, this one should do nothing.
    return if expected_run_time.present? && expected_run_time.to_f > scheduled_at.to_f

    lock_key = "batched_notifications_job_#{issue_id}"
    
    # Use a non-atomic lock compatible with FileStore.
    return if Rails.cache.read(lock_key)
    Rails.cache.write(lock_key, true, expires_in: 10.minutes)

    begin
      pending_notifications = PendingNotification.where(issue_id: issue_id)
      return if pending_notifications.empty?

      journals = Journal.where(id: pending_notifications.pluck(:journal_id))

      # Call the new mailer method which handles all recipient logic.
      Mailer.deliver_batch_issue_edits(journals) if journals.any?

      pending_notifications.destroy_all
    ensure
      Rails.cache.delete(lock_key) # Release lock
      Rails.cache.delete("notification_time_for_issue_#{issue_id}")
    end
  end
end