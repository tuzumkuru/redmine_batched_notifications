require_dependency 'journal'

module JournalPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method :send_notification_without_batch, :send_notification
      alias_method :send_notification, :send_notification_with_batch
    end
  end

  module InstanceMethods
    def send_notification_with_batch
      if Setting.plugin_redmine_batched_notifications['enabled'] == 'true' && issue.present? && user.present?
        # Mirror Redmine's core notification logic to decide if we should batch.
        should_notify = notify? && (
          Setting.notified_events.include?('issue_updated') ||
          (Setting.notified_events.include?('issue_note_added') && notes.present?) ||
          (Setting.notified_events.include?('issue_status_updated') && new_status.present?) ||
          (Setting.notified_events.include?('issue_assigned_to_updated') && detail_for_attribute('assigned_to_id').present?) ||
          (Setting.notified_events.include?('issue_priority_updated') && new_value_for('priority_id').present?) ||
          (Setting.notified_events.include?('issue_fixed_version_updated') && detail_for_attribute('fixed_version_id').present?) ||
          (Setting.notified_events.include?('issue_attachment_added') && details.any? { |d| d.property == 'attachment' && d.value })
        )

        if should_notify
          # Batch notifications on a per-user, per-issue basis.
          PendingNotification.create(issue_id: issue.id, journal_id: self.id, user_id: self.user_id)

          delay = Setting.plugin_redmine_batched_notifications['delay'].to_i.seconds
          scheduled_at = Time.now + delay

          cache_key = "notification_time_for_issue_#{issue.id}_user_#{self.user_id}"
          Rails.cache.write(cache_key, scheduled_at, expires_in: delay + 1.hour)

          SendBatchedNotificationsJob.set(wait: delay).perform_later(issue.id, self.user_id, scheduled_at.to_f)
        end
      else
        # If batching is disabled, fall back to Redmine's default behavior.
        send_notification_without_batch
      end
    end
  end
end

