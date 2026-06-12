class UnsubscribeController < ActionController::Base
  protect_from_forgery with: :null_session

  def show
    contact = find_contact_from_token
    return render plain: 'Invalid or expired link', status: :not_found unless contact

    mark_opted_out(contact)
    render plain: "Te has dado de baja. No recibirás más correos en #{contact.email}."
  end

  def process_unsubscribe
    contact = find_contact_from_token
    return head :not_found unless contact

    mark_opted_out(contact)
    head :ok
  end

  private

  def find_contact_from_token
    data = ResendComplianceHeaders.verify_unsubscribe_token(params[:token])
    return nil unless data

    Contact.where(account_id: data[:account_id]).find_by(id: data[:contact_id])
  end

  def mark_opted_out(contact)
    return if contact.custom_attributes['email_opted_out'] == true

    contact.update!(
      custom_attributes: contact.custom_attributes.merge('email_opted_out' => true, 'email_opted_out_at' => Time.current.iso8601)
    )
  end
end
