require 'rails_helper'
require 'huginn_agent/spec_helper'
require 'yaml'

require_relative '../lib/huginn_acumen_product_agent/acumen_client'

spec_folder = File.expand_path(File.dirname(__FILE__))
mock_data = YAML.load(File.read(spec_folder + "/acumen_product_agent_spec.yml"))

def mock_response(ns, ids)
    records = ids.map {|id| mock_data[ns][id]}
    response = <<~TEXT
        <?xml version="1.0" encoding="UTF-8"?>
        <SOAP-ENV:Envelope
        SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <SOAP-ENV:Body>
        <acusoapResponse>
          <result_set.#{ns}>#{records.join("\n")}</result_set.#{ns}>
        </acusoapResponse>
        </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
    TEXT
    response = ::MultiXml.parse(response, {})
    AcumenClient::get_results(response, ns)
end

allow(AcumenClient).to receive(:get_products) do |ids|
  mock_response('Inv_Product', ids)
end

allow(AcumenClient).to receive(:get_products_marketing) do |ids|
  mock_response('ProdMkt', ids)
end

allow(AcumenClient).to receive(:get_linked_products) do |ids|
  mock_response('Product_Link', ids)
end

allow(AcumenClient).to receive(:get_product_contributors) do |ids|
  mock_response('ProdMkt_Contrib_Link', ids)
end

allow(AcumenClient).to receive(:get_product_categories) do |ids|
  mock_response('ProdMkt_WPC', ids)
end


describe Agents::AcumenProductAgent do
  before(:each) do
    @valid_options = Agents::AcumenProductAgent.new.default_options
    @checker = Agents::AcumenProductAgent.new(:name => "AcumenProductAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
