class ProductBlueprintPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def by_name?
    @account_user.administrator?
  end

  def yaml_upload?
    @account_user.administrator?
  end

  def yaml_template?
    @account_user.administrator?
  end
end
