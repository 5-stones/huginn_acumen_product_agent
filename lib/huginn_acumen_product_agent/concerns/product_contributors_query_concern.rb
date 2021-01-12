# frozen_string_literal: true

# This module is responsible for reading/processing product Contributor data.
#
# The data in question here comes from multiple tables. The `ProdMkt_Contrib_Link`
# table defines the _relationship_ between products and contributors, and the
# `ProdMkt_Contributor` table defines the _contribution type_ (Author, Editor, etc)
module ProductContributorsQueryConcern
  extend AcumenQueryConcern

  # Updates the provided products with their associared contributor data
  def fetch_product_contributors(acumen_client, products)

    marketing_ids = products.map { |p| p['acumenAttributes']['product_marketing_id'] }
    contributor_data = acumen_client.get_product_contributors(marketing_ids)
    contributor_data = process_product_contributor_response(contributor_data)

    contributor_ids = contributor_data.map { |c| c['contributor_id'] }
    contributor_type_data = acumen_client.get_contributor_types(contributor_ids)
    contributor_type_data = process_contributor_type_response(contributor_type_data)

    return map_contributor_data(products, contributor_data, contributor_type_data)
  end

  # This function parses the raw data returned from the ProdMkt_Contrib_Link table
  # This table holds the relationship between products and Contributors
  # The resulting data is a hash mapping contributor arrays to Prod_Mkt.ID values
  def process_product_contributor_response(raw_data)
    contributors = []

    raw_data.each do |contributor|

      begin
        mapped = response_mapper(contributor, {
          'ProdMkt_Contrib_Link.ProdMkt_Contrib_ID' => 'contributor_id',
          'ProdMkt_Contrib_Link.ProdMkt_ID' => 'product_marketing_id',
          'ProdMkt_Contrib_Link.Inactive' => 'inactive',
        })

        if mapped['inactive'] == '0'
          contributors.push(mapped)
        end
      rescue => error
        issue_error(AcumenAgentError.new(
          'process_product_contributor_response',
          'Failed while processing contributor record',
          contributor,
          error,
        ))
      end
    end

    return contributors
  end

  # This function parses the raw data returned from the ProdMkt_Contributor table
  # This table holds the contributor type (e.g. Author) for the
  # contributor/product relationship
  def process_contributor_type_response(raw_data)
    results = {}
    raw_data.map do |contributor_type|

      begin
        mapped = response_mapper(contributor_type, {
          'ProdMkt_Contributor.ID' => 'contributor_id',
          'ProdMkt_Contributor.Contrib_Type' => 'type',
        })


        if !results[mapped['contributor_id']]
          results[mapped['contributor_id']] = mapped['type']
        end
      rescue => error
        issue_error(AcumenAgentError.new(
          'process_contributor_type_response',
          'Failed while processing contributor type record',
          contributor_type,
          error,
        ))
      end
    end

    return results
  end

  # This function maps parsed Contributor records to their matching Inv_Product record
  def map_contributor_data(products, contributor_data, contributor_type_data)
    products.each do |product|

      begin
        marketing_id = product['acumenAttributes']['product_marketing_id']
        contributors = contributor_data.select { |c| c['product_marketing_id'] == marketing_id }

        product['contributors'] = contributors.map do |c|
          {
            '@type' => 'Person',
            'identifier' => c['contributor_id'],
            'acumenAttributes' => {
              'contrib_type' => contributor_type_data[c['contributor_id']]
            }
          }
        end
      rescue => error
        issue_error(AcumenAgentError.new(
          'map_contributor_data',
          'Failed while mapping contributor data to products',
          { product: product, contributors: contributor_data, contributor_types: contributor_type_data },
          error
        ))
      end
    end

    return products
  end

end
