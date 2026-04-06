# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomAttributeDefinition do
  let(:account) { create(:account) }

  describe 'callbacks' do
    describe '#cleanup_conversation_required_attributes' do
      let(:account) { create(:account) }
      let(:attribute_key) { 'test_attribute' }
      let!(:custom_attribute) do
        create(:custom_attribute_definition,
               account: account,
               attribute_key: attribute_key,
               attribute_model: 'conversation_attribute')
      end

      context 'when conversation attribute is in required attributes list' do
        before do
          account.update!(conversation_required_attributes: [attribute_key, 'other_attribute'])
        end

        it 'removes the attribute from conversation_required_attributes when destroyed' do
          expect { custom_attribute.destroy! }
            .to change { account.reload.conversation_required_attributes }
            .from([attribute_key, 'other_attribute'])
            .to(['other_attribute'])
        end
      end

      context 'when attribute is contact_attribute' do
        let!(:contact_attribute) do
          create(:custom_attribute_definition,
                 account: account,
                 attribute_key: attribute_key,
                 attribute_model: 'contact_attribute')
        end

        before do
          account.update!(conversation_required_attributes: [attribute_key])
        end

        it 'does not modify conversation_required_attributes when destroyed' do
          expect { contact_attribute.destroy! }
            .not_to(change { account.reload.conversation_required_attributes })
        end
      end
    end
  end

  describe 'validations' do
    describe 'attribute_key format' do
      it 'allows alphanumeric keys with underscores' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order_date_1')
        expect(cad).to be_valid
      end

      it 'allows hyphens and dots' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order-date.v2')
        expect(cad).to be_valid
      end

      it 'allows Unicode letters' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: '客户类型')
        expect(cad).to be_valid
      end

      it 'rejects keys with single quotes' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: "x'||(SELECT 1)||'")
        expect(cad).not_to be_valid
        expect(cad.errors[:attribute_key]).to be_present
      end

      it 'rejects keys with spaces' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'order date')
        expect(cad).not_to be_valid
      end

      it 'rejects keys with semicolons' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'key; DROP TABLE users--')
        expect(cad).not_to be_valid
      end

      it 'rejects keys with parentheses' do
        cad = build(:custom_attribute_definition, account: account, attribute_key: 'key()')
        expect(cad).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#strip_attribute_key' do
      it 'strips leading and trailing whitespace from attribute_key' do
        cad = create(:custom_attribute_definition, account: account, attribute_key: '  order_date  ')
        expect(cad.attribute_key).to eq('order_date')
      end

      it 'strips leading and trailing whitespace from attribute_display_name' do
        cad = create(:custom_attribute_definition, account: account, attribute_display_name: '  Order Date  ')
        expect(cad.attribute_display_name).to eq('Order Date')
      end
    end
  end
end
