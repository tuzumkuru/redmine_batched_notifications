require_dependency 'mailer'

module MailerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      # This class method now receives a batch of journals from a single author.
      def self.deliver_batch_issue_edits(journals)
        # Get all potential recipients for this batch of changes.
        recipients = journals.flat_map do |journal|
          journal.notified_users | journal.notified_watchers | journal.notified_mentions | journal.journalized.notified_mentions
        end.uniq

        # For each recipient, filter the journals they can see and queue an email.
        recipients.each do |user|
          visible_journals = journals.select do |j|
            # A journal is visible if it's not private, OR if the user has permission to see private notes.
            # This ensures that private notes are only included for authorized users.
            is_public = !j.private_notes?
            can_view_private = user.allowed_to?(:view_private_notes, j.journalized.project)

            (is_public || can_view_private) && (j.notes.present? || j.visible_details(user).any?)
          end

          if visible_journals.any?
            batched_issue_edit(user, visible_journals).deliver_later
          end
        end
      end

      # Instance method for a single author's batched notifications.
      def batched_issue_edit(user, journals)
        issue = journals.first.journalized
        # Set the @author so Redmine's core mail filter can check for self-notification.
        @author = journals.first.user
        
        @issue = issue
        @user = user
        @journals = journals
        @issue_url = url_for(controller: 'issues', action: 'show', id: issue, anchor: "change-#{journals.last.id}")

        s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
        status_journal = journals.reverse.find { |j| j.new_value_for('status_id') }
        if status_journal && Setting.show_status_changes_in_mail_subject?
          status = IssueStatus.find_by(id: status_journal.new_value_for('status_id'))
          s += "(#{status.name}) " if status
        end
        s += issue.subject

        redmine_headers 'Project' => issue.project.identifier,
                        'Issue-Id' => issue.id
        message_id journals.first
        references issue

        mail to: user, subject: s
      end
    end
  end

  module InstanceMethods
    # No instance methods needed yet
  end
end

Mailer.send(:include, MailerPatch)