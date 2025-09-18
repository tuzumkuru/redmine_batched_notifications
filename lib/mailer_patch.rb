require_dependency 'mailer'

module MailerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      # Class method finds all potential recipients and calls the instance method
      # only for those who have visible journal entries with content.
      def self.deliver_batch_issue_edits(journals)
        # 1. Gather all potential users from all journals, like in core Redmine
        recipients = journals.flat_map do |journal|
          journal.notified_users | journal.notified_watchers | journal.notified_mentions | journal.journalized.notified_mentions
        end.uniq

        # 2. For each user, check for visible journals with content before queueing the email job
        recipients.each do |user|
          # A journal is included if it's visible AND has content for the user.
          visible_journals = journals.select do |j|
            j.visible?(user) && (j.notes.present? || j.visible_details(user).any?)
          end
          
          # Only deliver an email if there is something to show the user
          if visible_journals.any?
            batched_issue_edit(user, visible_journals).deliver_later
          end
        end
      end

      # Instance method for a single issue's batched notifications.
      def batched_issue_edit(user, journals)
        # All journals are for the same issue, guaranteed by the job.
        issue = journals.first.journalized
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
