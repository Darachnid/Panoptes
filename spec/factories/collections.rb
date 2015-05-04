FactoryGirl.define do
  factory :collection do
    sequence(:name) { |n| "collection_name_#{ n }" }
    sequence(:display_name) { |n| "another name #{ n }" }
    activated_state :active
    project
    private false

    association :owner, factory: :user

    factory :private_collection do
      private true
    end

    factory :collection_with_subjects do
      after(:create) do |col|
        create_list(:subject, 2, collections: [col], project: col.project)
      end
    end
  end
end
