# frozen_string_literal: true

class ScheduleBlock < ApplicationRecord
  belongs_to :account_user
  belongs_to :account

  before_validation :assign_account

  validates :day_of_week,   presence: true, inclusion: { in: 0..6 }
  validates :start_hour,    presence: true, inclusion: { in: 0..23 }
  validates :start_minutes, presence: true, inclusion: { in: 0..59 }
  validates :end_hour,      presence: true, inclusion: { in: 0..23 }
  validates :end_minutes,   presence: true, inclusion: { in: 0..59 }

  validates :account_user_id, uniqueness: {
    scope: %i[day_of_week start_hour start_minutes],
    message: 'already has a block at this time'
  }

  validate :end_after_start

  private

  def assign_account
    self.account_id = account_user&.account_id
  end

  def end_after_start
    return if start_hour.blank? || end_hour.blank?

    start_mins = (start_hour * 60) + start_minutes.to_i
    end_mins   = (end_hour   * 60) + end_minutes.to_i

    errors.add(:end_hour, 'must be after start time') if end_mins <= start_mins
  end
end
