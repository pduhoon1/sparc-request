class Ability
  include CanCan::Ability

  def initialize(user, protocol, sr, ssr, org)
    if user.is_super_user? || user.is_overlord?
      can :manage, :all
    else
      can :edit, ServiceRequest if user.can_edit_service_request?(sr)
      can :edit, SubServiceRequest if user.can_edit_sub_service_request?(ssr)
      can [:read, :edit], Protocol if user.can_view_protocol?(protocol)
      can :edit, Entity if user.can_edit_entity?(org, false)
      can :edit, Core if user.can_edit_core?(org.id)
      can :edit, Organization if user.can_edit_historical_data_for?(org)
    end
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
  end
end
