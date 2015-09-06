require 'rails_helper'

describe Ability do
  let(:pool) {FactoryGirl.create :pool}
  describe "pools" do
    describe "accessed by their owner" do
      let :ability  do
         Ability.new(pool.owner)
      end
      it "are readable" do
        ability.can?(:read, pool).should be_truthy
      end
      it "can be updated" do
        ability.can?(:update, pool).should be_truthy
      end
    end

    describe "accessed by a non-owner" do
      before do
        @non_owner = FactoryGirl.create(:identity)
      end
      let :ability do
        ability = Ability.new(@non_owner)
      end
      describe "with read access" do
        before do
          AccessControl.create!(identity: @non_owner, pool: pool, access: 'READ')
        end
        it "are queryable" do
          expect( ability.can?(:query, pool) ).to be_truthy
        end
        it "are readable" do
          ability.can?(:read, pool).should be_truthy
        end
        it "are not editable" do
          ability.can?(:edit, pool).should_not be_truthy
          ability.can?(:update, pool).should_not be_truthy
        end
      end
      describe "with edit access" do
        before do
          AccessControl.create!(identity: @non_owner, pool: pool, access: 'EDIT')
        end
        it "are queryable" do
          expect( ability.can?(:query, pool) ).to be_truthy
        end
        it "are readable" do
          ability.can?(:read, pool).should be_truthy
        end
        it "are editable" do
          ability.can?(:edit, pool).should be_truthy
          ability.can?(:update, pool).should be_truthy
        end
      end
      describe "with audience memberships" do
        let(:audience) do
          audience_category = pool.audience_categories.create
          audience_category.audiences.create
        end
        before do
          audience.members << @non_owner
          audience.save
        end
        it "are queryable" do
          expect( ability.can?(:query, pool) ).to be_truthy
        end
        it "are not readable" do
          ability.can?(:read, pool).should_not be_truthy
        end
        it "are not updatable" do
          ability.can?(:update, pool).should_not be_truthy
        end
      end
      context "by default" do
        it "are not queryable" do
          expect( ability.can?(:query, pool) ).to_not be_truthy
        end
        it "are not readable" do
          ability.can?(:read, pool).should_not be_truthy
        end
        it "are not updatable" do
          ability.can?(:update, pool).should_not be_truthy
        end
      end
    end

    it "can be created by a logged in user" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:create, Pool).should be_truthy
    end
    it "can't be created by a not logged in user" do
      ability = Ability.new(nil)
      ability.can?(:create, Pool).should_not be_truthy
    end
  end

  describe "nodes" do
    let(:node) {FactoryGirl.create :node, pool:pool}
    it "are readable by their owner" do
      ability = Ability.new(pool.owner)
      ability.can?(:read, node).should be_truthy
    end
    it "are not readable by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:read, node).should_not be_truthy
    end
    it "can be updated by an owner" do
      ability = Ability.new(pool.owner)
      ability.can?(:update, node).should be_truthy
    end
    it "can't be updated by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:update, node).should_not be_truthy
    end
    it "can be created by a logged in user" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:create, Node).should be_truthy
    end
    it "can't be created by a not logged in user" do
      ability = Ability.new(nil)
      ability.can?(:create, Node).should_not be_truthy
    end
  end
  describe "mapping_template" do
    before do
      @mapping_template = FactoryGirl.create(:mapping_template)
    end
    it "are readable by their owner" do
      ability = Ability.new(@mapping_template.pool.owner)
      ability.can?(:read, @mapping_template).should be_truthy
    end
    it "are not readable by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:read, @mapping_template).should_not be_truthy
    end
    it "can be updated by an owner" do
      ability = Ability.new(@mapping_template.pool.owner)
      ability.can?(:update, @mapping_template).should be_truthy
    end
    it "can't be updated by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:update, @mapping_template).should_not be_truthy
    end
    it "can be created by a logged in user" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:create, MappingTemplate).should be_truthy
    end
    it "can't be created by a not logged in user" do
      ability = Ability.new(nil)
      ability.can?(:create, MappingTemplate).should_not be_truthy
    end
  end
  describe "models" do
    before do
      @model = FactoryGirl.create :model
    end
    it "are readable by their owner" do
      ability = Ability.new(@model.pool.owner)
      ability.can?(:read, @model).should be_truthy
    end
    it "are not readable by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:read, @model).should_not be_truthy
    end
    describe "that don't have an owner (File model)" do
      it "are readable by anyone" do
        ability = Ability.new(FactoryGirl.create :identity)
        ability.can?(:read, Model.file_entity).should be_truthy
      end
    end
    it "can be updated by an owner" do
      ability = Ability.new(@model.pool.owner)
      ability.can?(:update, @model).should be_truthy
    end
    it "can't be updated by a non-owner" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:update, @model).should_not be_truthy
    end
    it "can be created by a logged in user" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:create, Model).should be_truthy
    end
    it "can't be created by a not logged in user" do
      ability = Ability.new(nil)
      ability.can?(:create, Model).should_not be_truthy
    end
  end


  describe "nodes" do
    before do
      @node = FactoryGirl.create :node
    end
    it "can be created by a logged in user" do
      ability = Ability.new(FactoryGirl.create :identity)
      ability.can?(:create, Node).should be_truthy
    end
    describe "accessed by a non-owner of the pool they are in" do
      before do
        @non_owner = FactoryGirl.create(:identity)
      end
      let :ability do
        ability = Ability.new(@non_owner)
      end
      describe "with read access" do
        before do
          AccessControl.create!(identity: @non_owner, pool: @node.pool, access: 'READ')
        end
        it "are readable" do
          ability.can?(:read, @node).should be_truthy
        end
        it "are not editable" do
          ability.can?(:edit, @node).should_not be_truthy
          ability.can?(:update, @node).should_not be_truthy
        end
      end
      describe "with edit access" do
        before do
          AccessControl.create!(identity: @non_owner, pool: @node.pool, access: 'EDIT')
        end
        it "are readable" do
          ability.can?(:read, @node).should be_truthy
        end
        it "are editable" do
          ability.can?(:edit, @node).should be_truthy
          ability.can?(:update, @node).should be_truthy
        end
      end

      it "are not readable" do
        ability.can?(:read, @node).should_not be_truthy
      end
      it "are not updatable" do
        ability.can?(:update, @node).should_not be_truthy
      end
    end
    describe "accessed by the owner of the pool they are in" do
      let :ability do
        ability = Ability.new(@node.pool.owner)
      end
      it "are readable by the owner of the pool they are in" do
        ability.can?(:read, @node).should be_truthy
      end
      it "can be updated by an owner" do
        ability.can?(:update, @node).should be_truthy
      end
    end
  end

  describe "exhibits" do
    before do
      @exhibit = FactoryGirl.create :exhibit
      @owner = Ability.new(@exhibit.pool.owner)
      @non_owner = Ability.new(FactoryGirl.create :identity)
      @not_logged_in = Ability.new(nil)
    end
    it "are readable by the owner of the pool they are in" do
      @owner.can?(:read, @exhibit).should be_truthy
    end
    it "are readable by a non-owner of the pool" do
      @non_owner.can?(:read, @exhibit).should be_truthy
    end
    it "are readable by a not logged in user" do
      @not_logged_in.can?(:read, @exhibit).should be_truthy
    end
    it "are editable by the owner of the pool they are in" do
      @owner.can?(:edit, @exhibit).should be_truthy
    end
    it "are not editable by a non-owner of the pool" do
      @non_owner.can?(:edit, @exhibit).should_not be_truthy
    end
    it "are updateable by the owner of the pool they are in" do
      @owner.can?(:update, @exhibit).should be_truthy
    end
    it "are not updateable by a non-owner of the pool" do
      @non_owner.can?(:update, @exhibit).should_not be_truthy
    end
    it "should be creatable by anyone" do
      @non_owner.can?(:create, Exhibit).should be_truthy
    end
    it "should not be creatable by anonymous" do
      ability = Ability.new(Identity.new)
      ability.can?(:create, Exhibit).should_not be_truthy
    end
  end

  describe "identities" do
    before do
      @identity = FactoryGirl.create :identity
      @owner = Ability.new(@identity)
      @non_owner = Ability.new(FactoryGirl.create :identity)
      @not_logged_in = Ability.new(nil)
    end
    it "are readable by everyone" do
      @owner.can?(:read, @identity).should be_truthy
      @non_owner.can?(:read, @identity).should be_truthy
      @not_logged_in.can?(:read, @identity).should be_truthy
    end

  end
end
