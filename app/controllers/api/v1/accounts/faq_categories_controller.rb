class Api::V1::Accounts::FaqCategoriesController < Api::V1::Accounts::BaseController
  before_action :faq_category, only: %i[show update destroy toggle_visibility move]
  before_action :check_authorization
  before_action :check_rate_limit, only: %i[create update destroy toggle_visibility move]

  def index
    @faq_categories = Current.account.faq_categories
                             .roots
                             .includes(:children, :faq_items)
                             .ordered
  end

  def tree
    @faq_categories = Current.account.faq_categories
                             .roots
                             .includes(children: [:children, :faq_items])
                             .ordered
  end

  def show; end

  def create
    @faq_category = Current.account.faq_categories.create!(
      faq_category_params.merge(created_by: current_user)
    )
    render :show, status: :created
  end

  def update
    @faq_category.update!(faq_category_params.merge(updated_by: current_user))
    render :show
  end

  def destroy
    @faq_category.destroy!
    head :ok
  end

  def toggle_visibility
    @faq_category.update!(is_visible: !@faq_category.is_visible, updated_by: current_user)
    render :show
  end

  def move
    new_parent_id = params[:parent_id]
    new_position = params[:position]&.to_i || 0

    @faq_category.update!(
      parent_id: new_parent_id.presence,
      position: new_position,
      updated_by: current_user
    )
    render :show
  end

  private

  def faq_category
    @faq_category ||= Current.account.faq_categories.find(params[:id])
  end

  def faq_category_params
    params.require(:faq_category).permit(:name, :description, :parent_id, :position, :is_visible)
  end

  def check_rate_limit
    operation_type = case action_name
                     when 'create' then :create
                     when 'update' then :update
                     when 'destroy' then :delete
                     when 'toggle_visibility' then :toggle
                     when 'move' then :move
                     else :create
                     end

    unless Faqs::RateLimiterService.acquire_lock(Current.account.id, operation_type, 'category')
      lock_info = Faqs::RateLimiterService.lock_info(Current.account.id, operation_type, 'category')
      remaining = lock_info&.dig(:remaining_seconds) || Faqs::RateLimiterService::RATE_LIMITS[operation_type]

      render json: {
        error: "Rate limit exceeded. Please wait #{remaining} seconds before trying again.",
        retry_after: remaining
      }, status: :too_many_requests
    end
  end
end
