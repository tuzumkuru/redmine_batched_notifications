class PendingNotification < ActiveRecord::Base
  belongs_to :issue
  belongs_to :journal
end