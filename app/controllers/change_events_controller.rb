class ChangeEventsController < ApplicationController
  before_action :ensure_debug_enabled

  def index
    @change_events = ChangeEvent.recent
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
