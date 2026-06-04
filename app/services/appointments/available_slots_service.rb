# frozen_string_literal: true

module Appointments
  class AvailableSlotsService
    MAX_DAYS     = 14
    MAX_OWNERS   = 20

    def initialize(account:, owner_ids:, start_date:, end_date:, slot_duration_minutes: nil)
      @account               = account
      @owner_ids             = Array(owner_ids).map(&:to_i)
      @start_date            = start_date
      @end_date              = end_date
      @slot_duration_minutes = slot_duration_minutes&.to_i || account.default_slot_duration
    end

    def call
      validate!

      account_users = @account.account_users.includes(:user).where(user_id: @owner_ids)
      valid_owner_ids = account_users.map(&:user_id)

      date_range  = (@start_date..@end_date).to_a
      days_of_week = date_range.map(&:wday).uniq

      working_hours  = WorkingHour.where(workable_type: 'AccountUser', workable_id: account_users.map(&:id), day_of_week: days_of_week)
      schedule_blocks = ScheduleBlock.where(account_user_id: account_users.map(&:id), day_of_week: days_of_week)
      appointments   = Appointment.kept
                                  .where(owner_id: valid_owner_ids, status: %i[scheduled in_progress])
                                  .where(scheduled_at: start_datetime..end_datetime)

      au_by_user_id        = account_users.index_by(&:user_id)
      wh_by_au_dow         = working_hours.group_by { [_1.workable_id, _1.day_of_week] }
      blocks_by_au_dow     = schedule_blocks.group_by { [_1.account_user_id, _1.day_of_week] }
      appts_by_owner_date  = appointments.group_by { [_1.owner_id, _1.scheduled_at.to_date] }

      agents_result    = {}
      by_datetime      = {}

      valid_owner_ids.each do |owner_id|
        au = au_by_user_id[owner_id]
        next unless au

        available_slots = {}

        date_range.each do |date|
          dow = date.wday
          wh  = (wh_by_au_dow[[au.id, dow]] || []).first

          next if wh.nil? || wh.closed_all_day?

          slots = generate_slots(date, wh, au, wh_by_au_dow, blocks_by_au_dow, appts_by_owner_date, owner_id)
          available_slots[date.iso8601] = slots.map { _1[:local] } unless slots.empty?

          slots.each do |slot|
            by_datetime[slot[:utc]] ||= []
            by_datetime[slot[:utc]] << owner_id
          end
        end

        agents_result[owner_id] = {
          name:            au.user.name,
          timezone:        au.timezone.presence || 'UTC',
          available_slots: available_slots
        }
      end

      { agents: agents_result, by_datetime: by_datetime }
    end

    private

    def validate!
      raise ArgumentError, 'owner_ids is required' if @owner_ids.empty?
      raise ArgumentError, 'Maximum 20 agents per request' if @owner_ids.size > MAX_OWNERS
      raise ArgumentError, 'Maximum date range is 14 days' if (@end_date - @start_date).to_i >= MAX_DAYS
    end

    def start_datetime
      @start_date.beginning_of_day
    end

    def end_datetime
      @end_date.end_of_day
    end

    def generate_slots(date, wh, au, wh_by_au_dow, blocks_by_au_dow, appts_by_owner_date, owner_id)
      tz       = au.timezone.presence || 'UTC'
      open_min  = (wh.open_hour  * 60) + wh.open_minutes
      close_min = (wh.close_hour * 60) + wh.close_minutes

      preloaded_wh     = wh_by_au_dow.values.flatten
      preloaded_blocks = blocks_by_au_dow.values.flatten
      existing_appts   = appts_by_owner_date[[owner_id, date]] || []

      slots = []
      cursor = open_min

      while cursor + @slot_duration_minutes <= close_min
        slot_hour = cursor / 60
        slot_min  = cursor % 60

        slot_local = Time.use_zone(tz) { Time.zone.local(date.year, date.month, date.day, slot_hour, slot_min, 0) }
        slot_utc   = slot_local.utc

        resolver = Appointments::ScheduleResolver.new(
          account_user:   au,
          datetime:       slot_utc,
          working_hours:  preloaded_wh,
          schedule_blocks: preloaded_blocks
        )

        if resolver.available? && !overlaps_appointment?(slot_utc, existing_appts)
          slots << { local: slot_local.iso8601, utc: slot_utc.iso8601 }
        end

        cursor += @slot_duration_minutes
      end

      slots
    end

    def overlaps_appointment?(slot_utc, appointments)
      slot_end = slot_utc + @slot_duration_minutes.minutes
      appointments.any? do |appt|
        appt_end = appt.ended_at.presence || (appt.scheduled_at + @slot_duration_minutes.minutes)
        slot_utc < appt_end && slot_end > appt.scheduled_at
      end
    end
  end
end
