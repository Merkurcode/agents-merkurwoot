# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appointments::ScheduleResolver do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:account_user) do
    au = user.account_users.find_by!(account: account)
    au.update!(timezone: 'UTC')
    au
  end

  # AccountUser auto-recibe: Lun–Vie 9-17, Sáb-Dom cerrados
  # Lunes 2026-06-08
  let(:monday_9am)   { Time.zone.parse('2026-06-08 09:00:00 UTC') }
  let(:monday_wh)    { account_user.working_hours.find_by!(day_of_week: 1) }
  let(:sunday_10am)  { Time.zone.parse('2026-06-07 10:00:00 UTC') } # domingo

  describe '#available?' do
    context 'cuando el día está cerrado (domingo, closed_all_day por defecto)' do
      it 'retorna false con razón :closed_all_day' do
        resolver = described_class.new(account_user: account_user, datetime: sunday_10am)
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:closed_all_day)
      end
    end

    context 'cuando no hay WH en datos precargados (batch con lista vacía)' do
      it 'retorna false con razón :closed_all_day' do
        resolver = described_class.new(
          account_user:    account_user,
          datetime:        monday_9am,
          working_hours:   [],
          schedule_blocks: []
        )
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:closed_all_day)
      end
    end

    context 'cuando el horario es open_all_day' do
      before { monday_wh.update!(open_all_day: true) }

      it 'retorna true sin importar la hora' do
        resolver = described_class.new(account_user: account_user, datetime: monday_9am)
        expect(resolver.available?).to be true
        expect(resolver.unavailability_reason).to be_nil
      end
    end

    context 'cuando el datetime cae fuera del horario laboral (Lun 9-17)' do
      it 'retorna false con razón :outside_hours para las 08:59' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 08:59:00 UTC'))
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:outside_hours)
      end

      it 'retorna false con razón :outside_hours para las 17:01' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 17:01:00 UTC'))
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:outside_hours)
      end
    end

    context 'cuando el datetime cae dentro del horario laboral' do
      it 'retorna true para las 09:00' do
        resolver = described_class.new(account_user: account_user, datetime: monday_9am)
        expect(resolver.available?).to be true
      end

      it 'retorna true para las 16:30' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 16:30:00 UTC'))
        expect(resolver.available?).to be true
      end
    end

    context 'cuando el datetime cae dentro de un schedule_block' do
      before do
        create(:schedule_block, account_user: account_user, day_of_week: 1,
                                start_hour: 12, start_minutes: 0,
                                end_hour: 13, end_minutes: 0)
      end

      it 'retorna false con razón :schedule_block a las 12:00' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 12:00:00 UTC'))
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:schedule_block)
      end

      it 'retorna false a las 12:30 (dentro del bloque)' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 12:30:00 UTC'))
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:schedule_block)
      end

      it 'retorna true a las 13:00 (justo al terminar el bloque)' do
        resolver = described_class.new(account_user: account_user, datetime: Time.zone.parse('2026-06-08 13:00:00 UTC'))
        expect(resolver.available?).to be true
      end
    end

    context 'con datos precargados (modo batch)' do
      let(:block) do
        create(:schedule_block, account_user: account_user, day_of_week: 1,
                                start_hour: 12, start_minutes: 0,
                                end_hour: 13, end_minutes: 0)
      end

      it 'evalúa correctamente disponible con datos precargados' do
        block
        resolver = described_class.new(
          account_user:    account_user,
          datetime:        monday_9am,
          working_hours:   [monday_wh],
          schedule_blocks: [block]
        )
        expect(resolver.available?).to be true
      end

      it 'detecta el bloque con datos precargados' do
        block
        resolver = described_class.new(
          account_user:    account_user,
          datetime:        Time.zone.parse('2026-06-08 12:30:00 UTC'),
          working_hours:   [monday_wh],
          schedule_blocks: [block]
        )
        expect(resolver.available?).to be false
        expect(resolver.unavailability_reason).to eq(:schedule_block)
      end
    end
  end
end
