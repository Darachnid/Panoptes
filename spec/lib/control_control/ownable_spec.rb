require 'spec_helper'

class Owned < ActiveRecord::Base
  extend ControlControl::Resource
  include ControlControl::Ownable

  def self.table_name
    "collections"
  end
end

describe ControlControl::Ownable, type: :model do
  let(:owned) do
    owned = Owned.new(name: "test")
    owned.owner = build(:user)
    owned
  end

  let(:not_owned) { Owned.new } 

  it_behaves_like "is ownable"
end
