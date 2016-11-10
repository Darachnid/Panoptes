require 'spec_helper'

describe Project, type: :model do
  let(:project) { build(:project) }
  let(:owned) { project }
  let(:not_owned) { build(:project, owner: nil) }
  let(:full_project) { create(:full_project) }
  let(:subject_relation) { full_project }
  let(:activatable) { project }
  let(:translatable) { create(:project_with_contents, build_extra_contents: true) }
  let(:translatable_without_content) { build(:project, build_contents: false) }
  let(:primary_language_factory) { :project }
  let(:locked_factory) { :project }
  let(:locked_update) { {display_name: "A Different Name"} }

  it_behaves_like "optimistically locked"
  it_behaves_like "is ownable"
  it_behaves_like "has subject_count"
  it_behaves_like "activatable"
  it_behaves_like "is translatable"
  it_behaves_like "has slugged name"

  describe ".scope_for" do
    let(:eager_loads) do
      [
         :workflows,
         :subject_sets,
         :project_contents,
         :pages,
         :avatar,
         :background,
         :attached_images,
         :tags
      ]
    end

    context "with enabled experiment" do
      before do
        Panoptes.flipper["eager_load_projects"].enable
        allow_any_instance_of(CodeExperiment).to receive(:enabled?).and_return(true)
      end

      it "should eager load the linked resources used in the serializer" do
        expect_any_instance_of(Project::ActiveRecord_Relation)
          .to receive(:eager_load)
          .with(*eager_loads)
          .and_call_original
        Project.scope_for(:index, ApiUser.new(nil))
      end

      it "should prealod the linked resources used in the serializer" do
        expect_any_instance_of(Project::ActiveRecord_Relation)
          .to receive(:preload)
          .with(:project_roles, owner: { identity_membership: :user })
          .and_call_original
        Project.scope_for(:index, ApiUser.new(nil))
      end

      it "should skip eager load if not set" do
        expect_any_instance_of(Project::ActiveRecord_Relation)
          .not_to receive(:eager_load)
        Project.scope_for(:index, ApiUser.new(nil), {skip_eager_load: true})
      end
    end
  end

  context "with caching resource associations" do
    let(:cached_resource) { full_project }

    it_behaves_like "has an extended cache key",
      [:project_contents, :tags],
      [:subjects_count, :retired_subjects_count, :finished?]
  end

  it "should have a valid factory" do
    expect(project).to be_valid
  end

  it 'should require unique displays name for an owner', :aggregate_failures do
    owner = create(:user)
    expect(create(:project, display_name: "hi fives", owner: owner)).to be_valid
    expect(build(:project, display_name: "hi fives", owner: owner)).to_not be_valid
    expect(build(:project, display_name: "HI fives", owner: owner)).to_not be_valid
  end

  it 'should not require display name uniquenames between owners', :aggregate_failures do
    expect(create(:project, display_name: "test project", owner: create(:user))).to be_valid
    expect(create(:project, display_name: "test project", owner: create(:user))).to be_valid
  end

  it 'should require a private field to be set' do
    expect(build(:project, private: nil)).to_not be_valid
  end

  it 'should require a live field to be set' do
    expect(build(:project, live: nil)).to_not be_valid
  end

  describe "links" do
    let(:user) { ApiUser.new(create(:user)) }

    it "should allow workflows to link when user has update permissions" do
      expect(Project).to link_to(Workflow).given_args(user)
                          .with_scope(:scope_for, :update, user)
    end

    it "should allow subject_sets to link when user has update permissions" do
      expect(Project).to link_to(SubjectSet).given_args(user)
                          .with_scope(:scope_for, :update, user)
    end

    it "should allow subjects to link when user has update permissions" do
      expect(Project).to link_to(Subject).given_args(user)
                          .with_scope(:scope_for, :update, user)
    end

    it "should allow collections to link user has show permissions" do
      expect(Project).to link_to(Collection).given_args(user)
                          .with_scope(:scope_for, :show, user)
    end
  end

  describe "#live" do
    before(:each) do
      project.update_attributes(live: nil)
    end

    it "should not accept nil values" do
      expect(project.valid?).to eq(false)
    end

    it "should have a useful error message" do
      project.valid?
      expect(project.errors[:live]).to include("must be true or false")
    end
  end

  describe "#workflows" do
    let(:project) { create(:project_with_workflows) }

    it "should have many workflows" do
      expect(project.workflows).to all( be_a(Workflow) )
    end
  end

  describe "#active_workflows" do
    let(:project) do
      create(:project) do |p|
        create(:workflow, project: p, active: true)
        create(:workflow, project: p, active: false)
      end
    end

    it "should only return the active workflow" do
      expect(project.active_workflows.size).to eq(1)
      expect(project.active_workflows).to all( be_a(Workflow) )
    end
  end

  describe "#subject_sets" do
    let(:project) { create(:project_with_subject_sets) }

    it "should have many subject_sets" do
      expect(project.subject_sets).to all( be_a(SubjectSet) )
    end
  end

  describe "#live_subject_sets" do
    let(:project) { full_project }
    let!(:unlinked_subject_set) do
      create(:subject_set, project: project)
    end

    it "should have many subject_sets" do
      expect(project.live_subject_sets).not_to include(unlinked_subject_set)
    end
  end

  describe "#classifications" do
    let(:relation_instance) { project }

    it_behaves_like "it has a classifications assocation"
  end

  describe "#subjects" do
    let(:relation_instance) { project }

    it_behaves_like "it has a subjects association"
  end

  describe "#project_roles" do
    let!(:preferences) do
      [create(:access_control_list, resource: project, roles: []),
       create(:access_control_list, resource: project, roles: ["tester"]),
       create(:access_control_list, resource: project, roles: ["collaborator"])]
    end

    it 'should include models with assigned roles' do
      expect(project.project_roles).to include(*preferences[1..-1])
    end

    it 'should not include models without assigned roles' do
      expect(project.project_roles).to_not include(preferences[0])
    end
  end

  describe "#tutorials" do
    let(:tutorial) { build(:tutorial, project: project) }

    it "should have many tutorial" do
      project.tutorials << tutorial
      expect(project.tutorials).to match_array([tutorial])
    end
  end

  describe "#field_guides" do
    let(:field_guide) { build(:field_guide, project: project) }

    it "should have many field_guides" do
      project.field_guides << field_guide
      expect(project.field_guides).to match_array([field_guide])
    end
  end

  describe "#expert_classifier_level and #expert_classifier?" do
    let(:project) { create(:project) }
    let(:project_user) { create(:user) }
    let(:roles) { [] }
    let!(:prefs) do
      create(:access_control_list, user_group: project_user.identity_group,
             resource: project,
             roles: roles)
    end

    context "when they are the project owner" do

      it '#expert_classifier_level should be :owner' do
        expect(project.expert_classifier_level(project.owner)).to eq(:owner)
      end

      it "#expert_classifier? should be truthy" do
        expect(project.expert_classifier?(project.owner)).to be_truthy
      end
    end

    context "when they are a project expert" do
      let!(:roles) { ["expert"] }

      it '#expert_classifier_level should be :expert' do
        expect(project.expert_classifier_level(project_user)).to eq(:expert)
      end

      it "#expert_classifier? should be truthy" do
        expect(project.expert_classifier?(project_user)).to be_truthy
      end
    end

    context "when they are an owner and they have marked themselves as a project expert" do
      let!(:project_user) { project.owner }
      let!(:prefs) do
        AccessControlList.where(user_group: project_user.identity_group,
                                resource: project)
          .first
          .update!(roles: ["owner", "expert"])
      end

      it '#expert_classifier_level should be :owner' do
        expect(project.expert_classifier_level(project_user)).to eq(:owner)
      end

      it "#expert_classifier? should be truthy" do
        expect(project.expert_classifier?(project_user)).to be_truthy
      end
    end

    context "when they are a project collaborator" do
      let!(:roles) { ["collaborator"] }

      it '#expert_classifier_level should be nil' do
        expect(project.expert_classifier_level(project_user)).to be_nil
      end

      it "#expert_classifier? should be falsey" do
        expect(project.expert_classifier?(project_user)).to be_falsey
      end
    end

    context "when they are a moderator and an expert project collaborator" do
      let!(:roles) { ["moderator", "expert"] }

      it '#expert_classifier_level should be :expert' do
        expect(project.expert_classifier_level(project_user)).to eq(:expert)
      end

      it "#expert_classifier? should be truthy" do
        expect(project.expert_classifier?(project_user)).to be_truthy
      end
    end

    context "when they have no role on the project" do

      it '#expert_classifier_level should be nil' do
        expect(project.expert_classifier_level(project_user)).to be_nil
      end

      it "#expert_classifier? should be falsey" do
        expect(project.expert_classifier?(project_user)).to be_falsey
      end
    end
  end

  describe "#retired_subjects_count" do
    let(:workflows) { full_project.workflows }
    before do
      workflows.map { |w| w.update_column(:retired_set_member_subjects_count, 1) }
    end

    it "return a count of the associated retired subjects" do
      expect(full_project.retired_subjects_count).to eq(1)
    end

    it "should not count inactive workflows" do
      workflows.sample.update_column(:active, false)
      expect(full_project.retired_subjects_count).to eq(0)
    end
  end

  describe "#finished?" do
    it "should return true when marked as finished via the enum" do
      full_project.finished!
      expect(full_project).to be_finished
    end

    context "no enum value set" do
      let(:workflows) { full_project.active_workflows }
      before do
        create(:workflow, project: full_project, active: false)
      end

      it 'should be true when all the active linked workflows are marked finished' do
        workflows.each do |w|
          allow(w).to receive(:finished?).and_return(true)
        end
        expect(full_project).to be_finished
      end

      it 'should be false when any of the active linked workflows are not marked finished' do
        expect(full_project).not_to be_finished
      end
    end
  end

  describe "#owners_and_collaborators" do
    let!(:collaborators) do
      project.save!
      col1 = create(:user)
      col2 = create(:user)
      expert = create(:user)

      create(:access_control_list, user_group: col1.identity_group, resource: project, roles: ["collaborator"])
      create(:access_control_list, user_group: col2.identity_group, resource: project, roles: ["collaborator"])
      create(:access_control_list, user_group: expert.identity_group, resource: project, roles: ["expert"])
      [col1, col2, expert]
    end

    it 'should load the owner' do
      expect(project.owners_and_collaborators.map(&:id)).to include(project.owner.id)
    end

    it 'should include the collaborators' do
      expect(project.owners_and_collaborators.map(&:id)).to include(*collaborators[0..1].map(&:id))
    end

    it 'should not include users with other roles' do
      expect(project.owners_and_collaborators.map(&:id)).to_not include(collaborators.last.id)
    end

    it 'should not include owners of other projects' do
      owner = create(:project).owner
      expect(project.owners_and_collaborators.map(&:id)).to_not include(owner.id)
    end
  end

  describe "#create_talk_admin" do
    let(:resource) { double(create: true) }
    let(:client) { double(roles: resource) }

    it 'should create roles' do
      project.save!
      expect(resource).to receive(:create).with(name: 'admin',
                                                user_id: project.owner.id,
                                                section: "project-#{project.id}")
      project.create_talk_admin(client)
    end
  end

  describe "#send_notifications" do

    context "when the project does not exist" do
      let(:project) { build(:project) }

      it 'should not call the callback' do
        expect(project).to_not receive(:send_notifications)
        project.save
      end
    end

    context "when the project does exist" do
      let(:project) { create(:project) }

      it 'should call the callback' do
        expect(project).to receive(:send_notifications)
        project.save
      end
    end

    context "when the project exists with inverted field values" do
      let!(:project) { create(:project, field => !value) }
      after(:each) do
        project.send("#{field}=", value)
        project.save!
      end

      context "when beta_requested changed" do
        let(:field) { "beta_requested" }

        context "when true" do
          let(:value) { true }
          it 'should queue the worker' do
            expect(ProjectRequestEmailWorker).to receive(:perform_async).with("beta", project.id)
          end
        end

        context "when false" do
          let(:value) { false }

          it 'should not queue the worker' do
            expect(ProjectRequestEmailWorker).not_to receive(:perform_async)
          end
        end
      end

      context "when launch_requested changed" do
        let(:field) { "launch_requested" }

        context "when true" do
          let(:value) { true }
          it 'should queue the worker' do
            expect(ProjectRequestEmailWorker).to receive(:perform_async).with("launch", project.id)
          end
        end

        context "when false" do
          let(:value) { false }

          it 'should not queue the worker' do
            expect(ProjectRequestEmailWorker).not_to receive(:perform_async)
          end
        end
      end
    end
  end
end
