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
      if Setting.plugin_redmine_batched_notifications['enabled'] == 'true' && issue.present?
        # Create a pending notification
        PendingNotification.create(issue_id: issue.id, journal_id: self.id)

        # Schedule the background job
        delay = Setting.plugin_redmine_batched_notifications['delay'].to_i.minutes
        SendBatchedNotificationsJob.set(wait: delay).perform_later(issue.id)
      else
        send_notification_without_batch
      end
    end
  end
end

Journal.send(:include, JournalPatch)