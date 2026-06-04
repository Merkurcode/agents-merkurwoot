# frozen_string_literal: true

module Appointments
  class ScheduleResolver
    attr_reader :unavailability_reason

    def initialize(account_user:, datetime:, working_hours: nil, schedule_blocks: nil)
      @account_user     = account_user
      @datetime         = datetime
      @working_hours    = working_hours
      @schedule_blocks  = schedule_blocks
    end

    def available?
      @unavailability_reason = nil

      local_time = @datetime.in_time_zone(timezone)
      dow = local_time.wday

      wh = working_hour_for(dow)

      if wh.nil? || wh.closed_all_day?
        @unavailability_reason = :closed_all_day
        return false
      end

      unless wh.open_all_day?
        open_time  = local_time.change(hour: wh.open_hour,  min: wh.open_minutes,  sec: 0)
        close_time = local_time.change(hour: wh.close_hour, min: wh.close_minutes, sec: 0)

        unless local_time.between?(open_time, close_time)
          @unavailability_reason = :outside_hours
          return false
        end
      end

      blocks = schedule_blocks_for(dow)
      if blocks.any? { |b| inside_block?(local_time, b) }
        @unavailability_reason = :schedule_block
        return false
      end

      true
    end

    private

    def timezone
      @account_user.timezone.presence || 'UTC'
    end

    def working_hour_for(dow)
      if @working_hours
        @working_hours.find { |wh| wh.workable_id == @account_user.id && wh.day_of_week == dow }
      else
        @account_user.working_hours.find_by(day_of_week: dow)
      end
    end

    def schedule_blocks_for(dow)
      if @schedule_blocks
        @schedule_blocks.select { |b| b.account_user_id == @account_user.id && b.day_of_week == dow }
      else
        @account_user.schedule_blocks.where(day_of_week: dow)
      end
    end

    def inside_block?(local_time, block)
      block_start = local_time.change(hour: block.start_hour, min: block.start_minutes, sec: 0)
      block_end   = local_time.change(hour: block.end_hour,   min: block.end_minutes,   sec: 0)
      local_time >= block_start && local_time < block_end
    end
  end
end
