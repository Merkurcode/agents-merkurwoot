# frozen_string_literal: true

FactoryBot.define do
  factory :product_catalog do
    sequence(:product_id) { |n| "PROD-#{n}" }
    sequence(:productName) { |n| "Product #{n}" }
    industry { 'Technology' }
    type { 'Software' }
    description { 'A test product' }
    listPrice { 99.99 }
    payment_options { 'CASH' }
    is_visible { true }
    account
  end

  factory :product_medium do
    file_type { 'IMAGE' }
    sequence(:file_name) { |n| "image_#{n}.jpg" }
    file_url { 'https://example.com/image.jpg' }
    file_size { 1024 }
    mime_type { 'image/jpeg' }
    s3_status { 'completed' }
    s3_key { 'test/image.jpg' }
    product_catalog
  end
end
