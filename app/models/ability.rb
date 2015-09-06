class Ability
  include CanCan::Ability

  def initialize(identity)
    #identity ||= Identity.new # guest user (not logged in)
    identity ||= Identity.anonymous_visitor # guest user (not logged in)

    # Logged in users:
    unless identity.new_record? || identity == Identity.anonymous_visitor
      alias_action :describe, :to => :read
      
      # The owner can read/edit/update it
      can [:read, :update], [Pool], :owner_id => identity.id
      can :read, Pool do |pool|
        pool.access_controls.where(:identity_id => identity.id ).any?
      end
      can :query, Pool do |pool|
        can?(:read, pool) || pool.audiences_for_identity(identity).any?
      end
      can :update, Pool do |pool|
        pool.access_controls.where(:identity_id => identity.id, :access=>'EDIT' ).any?
      end

      can [:read, :edit, :update, :destroy], [Node, Model, Exhibit, MappingTemplate, AudienceCategory, Audience] do |target|
        can? :update, target.pool
      end
      can :read, [Node, Model, Exhibit] do |target|
        can? :read, target.pool
      end


      # Allow read access to models without a pool (e.g. Model.file_entity)
      can :read, Model, :pool_id=>nil


      can :attach_file, Node, :pool=>{ :owner_id => identity.id}
      can :create, [Exhibit, Model, Node,  Pool, MappingTemplate]

    end


    can :read, Identity  #necessary for authorizing exhibit view (through identity)
    can :read, Exhibit
  end
end
