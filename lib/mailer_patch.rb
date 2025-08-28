require_dependency 'mailer'

module MailerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      def self.deliver_batched_issue_edit(issue, journal_ids)
        journals = Journal.where(id: journal_ids)
        users = journals.map(&:notified_users).reduce(:&)
        users.each do |user|
          batched_issue_edit(user, issue, journal_ids).deliver_later
        end
      end

      def batched_issue_edit(user, issue, journal_ids)
        redmine_headers 'Project' => issue.project.identifier,
                        'Issue-Tracker' => issue.tracker.name,
                        'Issue-Id' => issue.id,
                        'Issue-Author' => issue.author.login,
                        'Issue-Assignee' => assignee_for_header(issue)
        redmine_headers 'Issue-Priority' => issue.priority.name if issue.priority

        s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
        s += issue.subject
        @issue = issue
        @user = user
        @journals = Journal.where(id: journal_ids)
        @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue)

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