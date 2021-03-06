# frozen_string_literal: true

class CreateTaskUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :task_users do |t|
      t.references :task, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false

      t.timestamps
    end

    add_index :task_users, %i[user_id task_id], unique: true
  end
end
