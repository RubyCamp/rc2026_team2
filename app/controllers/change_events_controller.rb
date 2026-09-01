class ChangeEventsController < ApplicationController
  before_action :ensure_debug_enabled

  def index
    @change_events = ChangeEvent.source_debug.recent
  end

  def create
    case params.require(:kind)
    when "pending"
      ChangeEvent.create_debug!(review_status: :pending)
    when "reviewed"
      ChangeEvent.create_debug!(review_status: :reviewed)
    when "examples"
      ChangeEvent.create_debug_examples!
    else
      raise ActionController::BadRequest,
        "未対応のデバッグ操作です"
    end

    redirect_to(
      debug_change_events_path,
      notice: "表示確認用の変更記録を追加しました。"
    )
  end

  def destroy
    ChangeEvent.remove_debug!(id: params[:id])

    redirect_to(
      debug_change_events_path,
      notice: "表示確認用の変更記録を削除しました。"
    )
  end

  private

  def ensure_debug_enabled
    head :not_found unless ChangeEvent.debug_enabled?
  end
end
