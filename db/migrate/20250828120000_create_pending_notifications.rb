
class CreatePendingNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :pending_notifications do |t|
      t.integer :issue_id
      t.integer :journal_id
      t.datetime :created_at
    end
  end
end
