class AddUserIdToPendingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :pending_notifications, :user_id, :integer, null: false
    add_index :pending_notifications, [:issue_id, :user_id]
  end
end
