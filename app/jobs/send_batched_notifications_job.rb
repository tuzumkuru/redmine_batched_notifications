
class SendBatchedNotificationsJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id)
    pending_notifications = PendingNotification.where(issue_id: issue_id)
    return if pending_notifications.empty?

    issue = Issue.find(issue_id)
    journal_ids = pending_notifications.pluck(:journal_id)

    # Use a custom mailer to send the batched email
    Mailer.deliver_batched_issue_edit(issue, journal_ids)

    # Delete the pending notifications
    pending_notifications.destroy_all
  end
end
