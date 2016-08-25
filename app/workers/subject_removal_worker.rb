require 'subjects/remover'

class SubjectRemovalWorker
  include Sidekiq::Worker

  sidekiq_options queue: :data_low

  def perform(subject_id)
    Subjects::Remover.new(subject_id).cleanup
  end
end