class AcumenAgentError < StandardError
  attr_reader :scope, :data, :original_error

  def initialize(scope, message, data, original_error)
    @scope = scope
    @data = data
    @original_error = original_error
    super(message)
  end
end
