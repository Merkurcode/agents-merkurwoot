# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join 'spec/models/concerns/reauthorizable_shared.rb'

RSpec.describe Channel::Email do
  let(:channel) { create(:channel_email) }

  describe 'concerns' do
    it_behaves_like 'reauthorizable'

    context 'when prompt_reauthorization!' do
      it 'calls channel notifier mail for email' do
        admin_mailer = double
        mailer_double = double
        expect(AdministratorNotifications::ChannelNotificationsMailer).to receive(:with).and_return(admin_mailer)
        expect(admin_mailer).to receive(:email_disconnect).with(channel.inbox).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_later)
        channel.prompt_reauthorization!
      end
    end
  end

  it 'has a valid name' do
    expect(channel.name).to eq('Email')
  end

  context 'when microsoft?' do
    it 'returns false' do
      expect(channel.microsoft?).to be(false)
    end

    it 'returns true' do
      channel.provider = 'microsoft'
      expect(channel.microsoft?).to be(true)
    end
  end

  context 'when google?' do
    it 'returns false' do
      expect(channel.google?).to be(false)
    end

    it 'returns true' do
      channel.provider = 'google'
      expect(channel.google?).to be(true)
    end
  end

  describe 'resend provider' do
    let(:account) { create(:account) }

    it 'returns false from resend? for other providers' do
      expect(channel.resend?).to be(false)
    end

    it 'auto-configures SMTP settings on create when provider is resend' do
      resend_channel = described_class.create!(
        account: account,
        email: 'replies@notification.merkur.la',
        provider: 'resend'
      )

      expect(resend_channel.resend?).to be(true)
      expect(resend_channel.smtp_enabled).to be(true)
      expect(resend_channel.imap_enabled).to be(false)
      expect(resend_channel.smtp_address).to eq('smtp.resend.com')
      expect(resend_channel.smtp_port).to eq(587)
      expect(resend_channel.smtp_login).to eq('resend')
      expect(resend_channel.smtp_enable_starttls_auto).to be(true)
      expect(resend_channel.smtp_authentication).to eq('plain')
    end

    it 'returns RESEND_API_KEY env var as smtp_password when provider is resend' do
      resend_channel = described_class.create!(
        account: account,
        email: 'replies2@notification.merkur.la',
        provider: 'resend'
      )

      with_modified_env RESEND_API_KEY: 're_test_secret' do
        expect(resend_channel.smtp_password).to eq('re_test_secret')
      end
    end

    it 'returns the stored smtp_password for non-resend channels' do
      regular_channel = described_class.create!(
        account: account,
        email: 'manual@example.com',
        smtp_enabled: true,
        smtp_password: 'my-password'
      )

      with_modified_env RESEND_API_KEY: 'should-be-ignored' do
        expect(regular_channel.smtp_password).to eq('my-password')
      end
    end

    it 'returns the email domain as smtp_domain when provider is resend' do
      resend_channel = described_class.create!(
        account: account,
        email: 'replies@notification.merkur.la',
        provider: 'resend'
      )

      expect(resend_channel.smtp_domain).to eq('notification.merkur.la')
    end
  end
end
