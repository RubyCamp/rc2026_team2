class ChangeEventsController < ApplicationController
  before_action :ensure_debug_enabled

  def index
    @change_events = ChangeEvent.recent
    if params[:review_status].present?
      @change_events = @change_events.where(review_status: params[:review_status])
    end
  end

  def update
    ChangeEvent.mark_reviewed!(id: params[:id])

    redirect_to(
      change_events_path,
      notice: "表示確認用の変更記録を確認済みにしました。"
    )
  end

  private

  def ensure_debug_enabled
    head :not_found unless ChangeEvent.debug_enabled?
  end
end
