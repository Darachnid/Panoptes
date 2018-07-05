class SubjectPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve(action)
      parent_scope = policy_for(Project).scope_for(action)
      scope.where(project_id: parent_scope.select(:id))
    end
  end

  scope :index, :show, :update, :destroy, :update_links, :destroy_links, :versions, :version, with: Scope
end
