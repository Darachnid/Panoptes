class Api::V1::WorkflowsController < Api::ApiController
  doorkeeper_for :update, :create, :delete, scopes: [:project]

  def show
    workflow = Workflow.find(params[:id])
    load_cellect
    render json_api: WorkflowSerializer.resource(params)
  end

  def index
    render json_api: WorkflowSerializer.resource(params)
  end

  def update
    # TODO
  end

  def create
    workflow = Workflow.new creation_params
    workflow.save!
    json_api_render( 201,
                     WorkflowSerializer.resource(workflow),
                     api_workflow_url(workflow) )
  end

  def destroy
    workflow = Workflow.find params[:id]
    workflow.destroy!
    deleted_resource_response
  end

  private

  def creation_params
    params.require(:workflow)
      .permit(:name, :project_id, :pairwise, :grouped, :prioritized, :primary_language)
      .merge tasks: params[:workflow][:tasks]
  end

  def load_cellect
    return unless current_resource_owner
    Cellect::Client.connection.load_user(**cellect_params)
  end

  def cellect_params
    {
      host: cellect_host(params[:id]),
      user_id: current_resource_owner.id,
      workflow_id: params[:id]
    }
  end
end
