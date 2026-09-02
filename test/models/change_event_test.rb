require "test_helper"

class ChangeEventTest < ActiveSupport::TestCase
  setup do
    @older = ChangeEvent.record!(
      target_type: :work_request,
      target_id: 10,
      action_type: :created,
      summary: "勤務依頼を登録しました",
      occurred_at: Time.zone.local(2026, 7, 22, 9),
      source: :seed
    )

    @newer = ChangeEvent.record!(
      target_type: :assignment,
      target_id: 20,
      action_type: :assigned,
      summary: "スタッフを割り当てました",
      occurred_at: Time.zone.local(2026, 7, 22, 10),
      source: :operation
    )
  end

  test "recentは新しい変更から返す" do
    result = ChangeEvent.recent.where(
      id: [ @older.id, @newer.id ]
    )

    assert_equal [ @newer, @older ], result.to_a
  end

  test "pending_reviewとpending_countは未確認だけを対象にする" do
    ChangeEvent.mark_reviewed!(id: @older.id)

    result = ChangeEvent.pending_review.where(
      id: [ @older.id, @newer.id ]
    )

    assert_equal [ @newer ], result.to_a

    count = ChangeEvent
      .where(id: [ @older.id, @newer.id ])
      .pending_count

    assert_equal 1, count
  end

  test "mark_reviewed!は確認日時を保存して同じモデルを返す" do
    reviewed = ChangeEvent.mark_reviewed!(id: @newer.id)

    assert_equal @newer, reviewed
    assert_predicate reviewed, :review_status_reviewed?
    assert_not_nil reviewed.reviewed_at
  end

  test "mark_reviewed!は再実行すると確認状態をpendingにする" do
    second = ChangeEvent.mark_reviewed!(id: @newer.id).mark_reviewed!(id: @newer.id)

    assert_equal "pending", second.review_status
  end

  test "存在しないIDはRecordNotFoundを送出する" do
    missing_id = ChangeEvent.maximum(:id).to_i + 1

    assert_raises ActiveRecord::RecordNotFound do
      ChangeEvent.mark_reviewed!(id: missing_id)
    end

    assert_raises ActiveRecord::RecordNotFound do
      ChangeEvent.remove_debug!(id: missing_id)
    end
  end

  test "remove_debug!は条件を満たしたデバッグ記録だけ削除する" do
  with_rails_env("development") do
    with_env("ENABLE_CHANGE_EVENT_DEBUG", "true") do
      debug_event = ChangeEvent.record!(
        target_type: :work_request,
        target_id: nil,
        action_type: :updated,
        summary: "表示確認用の変更です",
        source: :debug
      )

      removed =
        ChangeEvent.remove_debug!(id: debug_event.id)

      assert_predicate removed, :destroyed?
    end
  end
end

  test "remove_debug!は正式な変更記録を削除しない" do
    with_rails_env("development") do
      with_env("ENABLE_CHANGE_EVENT_DEBUG", "true") do
        assert_raises ActiveRecord::RecordNotDestroyed do
          ChangeEvent.remove_debug!(id: @newer.id)
        end
      end
    end

    assert_predicate @newer.reload, :persisted?
  end

 test "デバッグ機能は環境変数がtrueの開発環境だけ有効になる" do
  with_rails_env("development") do
    with_env("ENABLE_CHANGE_EVENT_DEBUG", "true") do
      assert_predicate ChangeEvent, :debug_enabled?
    end

    with_env("ENABLE_CHANGE_EVENT_DEBUG", "false") do
      assert_not_predicate ChangeEvent, :debug_enabled?
    end
  end

  with_rails_env("production") do
    with_env("ENABLE_CHANGE_EVENT_DEBUG", "true") do
      assert_not_predicate ChangeEvent, :debug_enabled?
    end
  end
end

  private

def with_env(name, value)
  previous = ENV[name]
  ENV[name] = value
  yield
ensure
  ENV[name] = previous
end

def with_rails_env(name)
  previous = Rails.instance_variable_get(:@_env)

  Rails.instance_variable_set(
    :@_env,
    ActiveSupport::EnvironmentInquirer.new(name)
  )

  yield
ensure
  Rails.instance_variable_set(:@_env, previous)
end
end
