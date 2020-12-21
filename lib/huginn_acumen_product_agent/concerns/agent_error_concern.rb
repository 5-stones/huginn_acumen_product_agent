# frozen_string_literal: true

module AgentErrorConcern
  extend ActiveSupport::Concern

  def issue_error(error, status = 500)
    # NOTE: Status is intentionally included on the top-level payload so that other
    # agents can look for a `payload[:status]` of either 200 or 500 to distinguish
    # between success and failure states
    create_event payload: {
      status: status,
      scope: error.scope,
      message: error.message,
      original_error: error.original_error,
      data: error.data,
      trace: error.original_error.backtrace,
    }
  end
end
