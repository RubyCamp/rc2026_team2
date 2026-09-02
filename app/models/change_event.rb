class ChangeEvent < ApplicationRecord
    DEBUG_EXAMPLES = [
    [
      :work_request,
      :created,
      "表示確認用：勤務依頼を登録しました"
    ],
    [
      :work_request,
      :updated,
      "表示確認用：勤務依頼を更新しました"
    ],
    [
      :availability,
      :updated,
      "表示確認用：勤務可否を更新しました"
    ],
    [
      :assignment,
      :assigned,
      "表示確認用：スタッフを仮割当しました"
    ],
    [
      :assignment,
      :unassigned,
      "表示確認用：スタッフの割当を解除しました"
    ]
  ].freeze
  enum :target_type,
       {
         work_request: "work_request",
         availability: "availability",
         assignment: "assignment"
       },
       prefix: true,
       validate: true

  enum :action_type,
       {
         created: "created",
         updated: "updated",
         cancelled: "cancelled",
         deleted: "deleted",
         assigned: "assigned",
         confirmed: "confirmed",
         unassigned: "unassigned"
       },
       prefix: true,
       validate: true

  enum :review_status,
       {
         pending: "pending",
         reviewed: "reviewed"
       },
       prefix: true,
       validate: true

  enum :source,
       {
         operation: "operation",
         seed: "seed",
         debug: "debug"
       },
       prefix: true,
       validate: true

  validates :summary, :occurred_at, presence: true

  def self.recent
    order(occurred_at: :desc, id: :desc)
  end

  def self.pending_review
    where(review_status: :pending).recent
  end

  def self.pending_count
    pending_review.count
  end

  def self.record!(
    target_type:,
    target_id:,
    action_type:,
    summary:,
    occurred_at: Time.current,
    source: :operation,
    review_status: :pending,
    reviewed_at: nil
  )
      ensure_debug_enabled! if source.to_s == "debug"
    create!(
      target_type: target_type,
      target_id: target_id,
      action_type: action_type,
      summary: summary,
      occurred_at: occurred_at,
      source: source,
      review_status: review_status,
      reviewed_at: reviewed_at
    )
  end
  def self.create_debug!(review_status: :pending)
    reviewed_at =
      if review_status.to_s == "reviewed"
        Time.current
      end

    record!(
      target_type: :work_request,
      target_id: nil,
      action_type: :updated,
      summary: "表示確認用の変更記録です",
      source: :debug,
      review_status: review_status,
      reviewed_at: reviewed_at
    )
  end

  def self.create_debug_examples!
    transaction do
      DEBUG_EXAMPLES.each_with_index.map do |example, index|
        target_type, action_type, summary = example

        record!(
          target_type: target_type,
          target_id: nil,
          action_type: action_type,
          summary: summary,
          occurred_at: Time.current - index.minutes,
          source: :debug
        )
      end
    end
  end
  def self.mark_reviewed!(id:)
    find(id).tap do |change_event|
      if change_event.review_status == "pending"
        change_event.update!(
          review_status: :reviewed,
          reviewed_at: Time.current
        )
      elsif change_event.review_status == "reviewed"
        change_event.update!(
          review_status: :pending,
          reviewed_at: nil
        )
      end
    end
  end

  def self.remove_debug!(id:)
    find(id).tap do |change_event|
      unless debug_enabled? && change_event.source_debug?
        message = "開発用の変更記録だけ削除できます"
        change_event.errors.add(:base, message)

        raise ActiveRecord::RecordNotDestroyed.new(
          message,
          change_event
        )
      end

      change_event.destroy!
    end
  end

    def self.debug_enabled?
      Rails.env.development? &&
      ENV["ENABLE_CHANGE_EVENT_DEBUG"] == "true"
    end

  def self.ensure_debug_enabled!
    return if debug_enabled?

    change_event = new

    change_event.errors.add(
      :base,
      "変更記録のデバッグ機能は無効です"
    )

    raise ActiveRecord::RecordInvalid, change_event
  end

  private_class_method :ensure_debug_enabled!
end
