require 'rails_helper'

RSpec.describe DataImport::TagsManager do
  let!(:account) { create(:account) }
  let!(:contact) { create(:contact, account: account, identifier: '123') }
  let(:ruby_tag) { ActsAsTaggableOn::Tag.find_or_create_by!(name: 'ruby') }
  let(:rails_tag) { ActsAsTaggableOn::Tag.find_or_create_by!(name: 'rails') }

  before do
    account.labels.create!(title: ruby_tag.name)
    account.labels.create!(title: rails_tag.name)
  end

  describe '#build' do
    subject(:manager) { described_class.new(account) }

    context 'when tags param is blank' do
      it 'does nothing' do
        expect do
          manager.build(identifier: '123', tags: '')
        end.not_to(change { contact.reload.label_list })
      end
    end

    context 'when contact does not exist' do
      it 'does nothing' do
        expect do
          manager.build(identifier: '999', tags: 'ruby, rails')
        end.not_to(change { ActsAsTaggableOn::Tagging.count })
      end
    end

    context 'when tags are valid' do
      it 'assigns only valid tags to the contact' do
        tag_instances = manager.build(identifier: '123', tags: 'ruby, invalid_tag')

        expect(tag_instances.count).to eq(1)
        expect(tag_instances.first.tag_id).to eq(ruby_tag.id)
      end
    end

    context 'when tags have spaces and case differences' do
      it 'normalizes tags before assignment' do
        tag_instances = manager.build(identifier: '123', tags: ' Ruby ,  RAILS ')

        expect(tag_instances.count).to eq(2)
        expect(tag_instances.first.tag_id).to eq(ruby_tag.id)
        expect(tag_instances.last.tag_id).to eq(rails_tag.id)
      end
    end
  end
end
