class SendBatchedNotificationsJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, user_id, scheduled_at_timestamp)
    scheduled_at = Time.at(scheduled_at_timestamp)

    time_cache_key = "notification_time_for_issue_#{issue_id}_user_#{user_id}"
    expected_run_time = Rails.cache.read(time_cache_key)

    # Abort if a newer job has been enqueued for this issue and user.
    return if expected_run_time.present? && expected_run_time.to_f > scheduled_at.to_f

    lock_key = "batched_notifications_job_#{issue_id}_user_#{user_id}"

    # Use a non-atomic lock to prevent concurrent job execution.
    return if Rails.cache.read(lock_key)
    Rails.cache.write(lock_key, true, expires_in: 10.minutes)

    begin
      pending_notifications = PendingNotification.where(issue_id: issue_id, user_id: user_id)
      return if pending_notifications.empty?

      journals = Journal.where(id: pending_notifications.pluck(:journal_id))

      Mailer.deliver_batch_issue_edits(journals) if journals.any?

      pending_notifications.destroy_all
    ensure
      Rails.cache.delete(lock_key)
      Rails.cache.delete(time_cache_key)
    end
  end
end