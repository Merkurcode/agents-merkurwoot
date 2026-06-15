class EnrollmentResultValue < ApplicationRecord
  belongs_to :sequence_enrollment
  belongs_to :lead_follow_up_sequence

  validates :field_key, presence: true

  scope :for_sequence, ->(id) { where(lead_follow_up_sequence_id: id) }
  scope :for_field,    ->(key) { where(field_key: key) }
end
