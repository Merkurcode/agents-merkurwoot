class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'
    return supervisor_accessible_conversations if user_role == 'supervisor'

    accessible_conversations
  end

  private

  def accessible_conversations
    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  def supervisor_accessible_conversations
    own_inbox_ids = user.inboxes.where(account_id: account.id).pluck(:id)
    subordinate_ids = account_user.all_subordinate_user_ids

    conversations.where(
      'inbox_id IN (?) OR assignee_id IN (?)',
      own_inbox_ids,
      subordinate_ids
    )
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
