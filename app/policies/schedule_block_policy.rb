class ScheduleBlockPolicy < ApplicationPolicy
  def index?
    administrator_or_own_agent?
  end

  def create?
    administrator_or_own_agent?
  end

  def update?
    administrator_or_own_agent?
  end

  def destroy?
    administrator_or_own_agent?
  end

  private

  def administrator_or_own_agent?
    @account_user.administrator? || @account_user.supervisor? || @user.id == @record.try(:user_id)
  end
end
