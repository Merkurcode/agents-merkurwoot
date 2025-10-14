class Api::V1::Accounts::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :appointment, except: [:index, :create]
  before_action :check_authorization

  def index
    @appointments = Current.account.appointments.includes(:contact).order(start_time: :desc)
  end

  def show; end

  def create
    contact = Current.account.contacts.find(params[:contact_id])
    @appointment = contact.appointments.create!(appointment_params)
  end

  def update
    @appointment.update!(appointment_params)
  end

  def destroy
    @appointment.destroy!
    head :ok
  end

  private

  def appointment
    @appointment ||= Current.account.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(:location, :description, :start_time, :end_time)
  end
end
