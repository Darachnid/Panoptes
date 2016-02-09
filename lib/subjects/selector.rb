module Subjects
  class Selector
    class MissingParameter < StandardError; end
    class MissingSubjectQueue < StandardError; end
    class MissingSubjectSet < StandardError; end
    class MissingSubjects < StandardError; end

    attr_reader :user, :params, :workflow

    def initialize(user, workflow, params, scope)
      @user, @workflow, @params, @scope = user, workflow, params, scope
    end

    def queued_subjects
      raise workflow_id_error unless workflow
      raise group_id_error if needs_set_id?
      raise missing_subject_set_error if workflow.subject_sets.empty?
      raise missing_subjects_error if workflow.set_member_subjects.empty?
      unless queue = user_subject_queue
        raise MissingSubjectQueue.new("No queue defined for user. Building one now, please try again.")
      end
      [ selected_subjects(queue), queue_context.merge(selected: true, url_format: :get) ]
    end

    def selected_subjects(queue)
      sms_ids = sms_ids_from_queue(queue)
      @scope.eager_load(:set_member_subjects)
        .where(set_member_subjects: {id: sms_ids})
        .order("idx(array[#{sms_ids.join(',')}], set_member_subjects.id)")
    end

    private

    def sms_ids_from_queue(queue)
      sms_ids = queue.next_subjects(subjects_page_size)
      non_retired_ids = filter_non_retired(sms_ids)

      if non_retired_ids.blank?
        fallback_selection
      else
        dequeue_for_logged_in_user(sms_ids) # dequeue all including retired ids
        non_retired_ids
      end
    end

    def filter_non_retired(sms_ids)
      retired_ids = SetMemberSubject
        .joins("INNER JOIN subject_workflow_counts ON subject_workflow_counts.subject_id = set_member_subjects.subject_id")
        .where("subject_workflow_counts.retired_at IS NOT NULL")
        .where(set_member_subjects: {id: sms_ids})
        .pluck(:id)

      retired_ids = Set.new(retired_ids)
      sms_ids.reject {|id| retired_ids.include?(id) }
    end

    def fallback_selection(limit=5)
      opts = { limit: limit, subject_set_id: subject_set_id }
      selector = PostgresqlSelection.new(workflow, user.user, opts)
      sms_ids = selector.select
      return sms_ids unless sms_ids.blank?
      selector.any_workflow_data
    end

    def needs_set_id?
      workflow.grouped && !params.has_key?(:subject_set_id)
    end

    def workflow_id_error
      MissingParameter.new("workflow_id parameter missing")
    end

    def group_id_error
      MissingParameter.new("subject_set_id parameter missing for grouped workflow")
    end

    def missing_subject_set_error
      MissingSubjectSet.new("no subject set is associated with this workflow")
    end

    def missing_subjects_error
      MissingSubjects.new("No data available for selection")
    end

    def subjects_page_size
      page_size = params[:page_size] ? params[:page_size].to_i : 10
      params.merge!(page_size: page_size)
      page_size
    end

    def finished_workflow?
      @finished_workflow ||= workflow.finished? || user.has_finished?(workflow)
    end

    def queue_user
      @queue_user ||= finished_workflow? ? nil : user.user
    end

    def queue_context
      @queue_context ||= {
        workflow: workflow,
        user_seen: UserSeenSubject.where(user: user.user, workflow: workflow)
      }
    end

    def subject_set_id
      params[:subject_set_id]
    end

    def user_subject_queue
      if queue = find_subject_queue
        queue
      else
        SubjectQueue.create_for_user(workflow, queue_user, set_id: subject_set_id)
      end
    end

    def find_subject_queue(user=queue_user)
      SubjectQueue.by_set(subject_set_id)
        .find_by(user: user, workflow: workflow)
    end

    def dequeue_for_logged_in_user(sms_ids)
      if queue_user
        DequeueSubjectQueueWorker.perform_async(workflow.id, sms_ids, queue_user.try(:id), subject_set_id)
      end
    end
  end
end