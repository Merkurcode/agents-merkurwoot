module Enterprise::SearchService
  def advanced_search
    where_conditions = { account_id: current_account.id }

    unless should_skip_inbox_filtering?
      if account_user.supervisor?
        # Supervisor solo ve mensajes de conversaciones asignadas a sí mismo o a sus subordinados
        supervisor_assignee_ids = account_user.all_subordinate_user_ids + [current_user.id]
        conversation_ids = current_account.conversations
                                          .where(assignee_id: supervisor_assignee_ids)
                                          .pluck(:id)
        where_conditions[:conversation_id] = conversation_ids
      else
        where_conditions[:inbox_id] = accessable_inbox_ids
      end
    end

    Message.search(
      search_query,
      fields: %w[content attachments.transcribed_text content_attributes.email.subject],
      where: where_conditions,
      order: { created_at: :desc },
      page: params[:page] || 1,
      per_page: 15
    )
  end
end
