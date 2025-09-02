require_dependency 'mailer'

module MailerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      def self.deliver_batched_issue_edit(user, issue, journal_ids, author = nil)
        batched_issue_edit(user, issue, journal_ids, author).deliver_later
      end

      def batched_issue_edit(user, issue, journal_ids, author = nil)
        redmine_headers 'Project' => issue.project.identifier,
                        'Issue-Tracker' => issue.tracker.name,
                        'Issue-Id' => issue.id,
                        'Issue-Author' => issue.author.login,
                        'Issue-Assignee' => issue.assigned_to.try(:name) || ''
        redmine_headers 'Issue-Priority' => issue.priority.try(:name) || '' if issue.priority

        s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
        s += "#{issue.subject}"
        @issue = issue
        @user = user
        @journals = Journal.where(id: journal_ids)
        @author = author  # Make author available in views
        @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue.id)

        mail :to => user,
          :subject => s
      end
    end
  end

  module InstanceMethods
    # No instance methods needed yet
  end
end

Mailer.send(:include, MailerPatch)