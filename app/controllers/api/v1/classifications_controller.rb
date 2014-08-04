class Api::V1::ClassificationsController < Api::ApiController
  doorkeeper_for :show, :index, scopes: [:classifications]

  def show
    render json_api: ClassificationSerializer.resource(params)
  end

  def index
    render json_api: ClassificationSerializer.page(params)
  end

  def create
    classification = Classification.new(creation_params)
    classification.user_ip = request_ip
    if user = api_user
      update_cellect
      classification.user = user
    end
    if classification.save!
      uss_params = user_seen_subject_params(user)
      UserSeenSubjectUpdater.update_user_seen_subjects(uss_params)
      create_project_preference
      json_api_render( 201,
                       ClassificationSerializer.resource(classification),
                       api_classification_url(classification) )
    end
  end

  private

  def create_project_preference
    return unless api_user
    UserProjectPreference.where(user: api_user, **preference_params)
      .first_or_create do |up|
        up.email_communication = api_user.project_email_communication
        up.preferences = {}
      end
  end

  def update_cellect
    Cellect::Client.connection.add_seen(**cellect_params)
  end

  def classification_params
    params.require(:classification)
  end

  def permitted_cellect_params
    classification_params.permit(:workflow_id, :subject_id)
  end

  def cellect_params
    permitted_cellect_params
      .merge(user_id: api_user.id,
             host: cellect_host(params[:workflow_id]))
      .symbolize_keys
  end

  def preference_params
    classification_params.permit(:project_id).symbolize_keys
  end

  def creation_params
    permitted_attrs = [ :project_id,
                        :workflow_id,
                        :set_member_subject_id ]
    classification_params.permit(*permitted_attrs).tap do |white_listed|
      white_listed[:annotations] = params[:classification][:annotations]
    end
  end

  def user_seen_subject_params(user)
    user_id = user ? user.id : nil
    params = permitted_cellect_params
               .slice(:subject_id, :workflow_id)
               .merge(user_id: user_id)
    params.symbolize_keys
  end
end
