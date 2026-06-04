# frozen_string_literal: true

class CreateScheduleBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table :schedule_blocks do |t|
      t.references :account_user, null: false, foreign_key: true
      t.bigint     :account_id,    null: false
      t.integer    :day_of_week,   null: false
      t.integer    :start_hour,    null: false
      t.integer    :start_minutes, null: false, default: 0
      t.integer    :end_hour,      null: false
      t.integer    :end_minutes,   null: false, default: 0
      t.string     :reason
      t.timestamps
    end

    add_index :schedule_blocks, %i[account_user_id day_of_week]
    add_index :schedule_blocks, :account_id
    add_index :schedule_blocks, %i[account_user_id day_of_week start_hour start_minutes], unique: true,
              name: 'index_schedule_blocks_on_owner_dow_start'
  end
end
