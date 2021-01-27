# frozen_string_literal: true

# This module is responsible for reading/processing data from the ProdMkt_WPC table
# NOTE:  Records on this table are linked to products by SKU
module ProductCategoriesQueryConcern
  extend AcumenQueryConcern

  # Updates the provided products with their associated category data
  def fetch_product_categories(acumen_client, products)

    product_skus = products.map { |p| p['sku'] }
    category_data = acumen_client.get_product_categories(product_skus)
    category_data = process_product_category_response(category_data)

    return map_category_data(products, category_data)
  end

  # This function parses the raw data returned from the ProdMkt_WPC table
  # This table holds the relationship between products and Web Categories
  # The resulting data contains arrays of Category records keyed to product SKUs
  #
  # NOTE: In the Acumen data, some Category assignments are marked as inactive.
  # This function only returns _active_ categories in the resulting data.
  def process_product_category_response(raw_data)
    results = {}

    raw_data.map do |product_category|

      begin
        mapped = response_mapper(product_category, {
          'ProdMkt_WPC.ProdCode' => 'sku',
          'ProdMkt_WPC.WPC_ID' => 'category_id',
          'ProdMkt_WPC.Inactive' => 'inactive',
        })

        product_sku = mapped['sku']

        if results[product_sku]
          results[product_sku].push(mapped) if mapped['inactive'] == '0'
        else
          results[product_sku] = [mapped] if mapped['inactive'] == '0'
        end
      rescue => error
        issue_error(AcumenAgentError.new(
          'process_product_category_response',
          'Failed while processing category data',
          product_category,
          error,
        ))
      end
    end

    results
  end

  # This function maps parsed Web Category records to their matching Product
  def map_category_data(products, category_data)
    products.each do |product|
      product['categories'] = []
      categories = category_data[product['sku']]

      unless categories.nil?
        categories.map do |cat|
          product['categories'].push({
            '@type' => 'Thing',
            'identifier' => cat['category_id']
          })
        end
      end
    end

    return products
  end
end
