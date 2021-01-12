# frozen_string_literal: true

# This module contains the baseline utility methods used in the more specific
# data concerns
module AcumenQueryConcern
  extend ActiveSupport::Concern

  UNIT_MAP = {
    'oz.' => 'OZ',
    'Inches (US)' => 'INH',
  }

  protected

  # Maps Acumen XML data to a hash object as specified in the provided `field_map`
  # The field map is a hash of { source_field: target_field }
  def response_mapper(data, field_map)
    result = {}

    field_map.each do |source_field, target_field|
      result[target_field] = get_field_value(data, source_field)
    end

    return result
  end

  # Utility function to retrieve a value from an XML field
  def get_field_value(data, field_name)
    data[field_name]['__content__'] if data[field_name]
  end

  # Returns a quantitative field value (e.g. weight) as a Schema.org/QuantitativeValue
  # object
  def get_quantitative_value(value, unit)
    {
      '@type' => 'QuantitativeValue',
      'value' => value,
      'unitText' => unit,
      'unitCode' => (UNIT_MAP[unit] if unit),
    } if value
  end

  # Emits an error payload event to facilitate better debugging/logging
  # NOTE: The `error` here is expected to be an instance of AcumenAgentError
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
