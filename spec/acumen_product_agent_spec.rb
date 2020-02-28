require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::AcumenProductAgent do
  before(:each) do
    @valid_options = Agents::AcumenProductAgent.new.default_options
    @checker = Agents::AcumenProductAgent.new(:name => "AcumenProductAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
