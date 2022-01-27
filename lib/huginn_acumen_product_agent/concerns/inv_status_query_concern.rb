# frozen_string_literal: true

# This module is responsible for reading/processing the Inv_Status table. This table
# contains stock information for the product and is tied to product availability.
module ProdMktQueryConcern
  extend AcumenQueryConcern

  # Update the provided products with their associated marketing data
  # NOTE: The `products` here are Shema.org/Product records mapped from Inv_Product
  # data
  def fetch_inv_status(acumen_client, products)

    product_skus = products.map { |p| p['sku'] }
    inventory_data = acumen_client.get_inv_status(product_skus)
    inventory_data = process_inv_status_response(inventory_data)

    return map_inv_status_data(products, inventory_data)
  end

  # This function parses the raw data returned from the Prod_Mkt table
  def process_inv_status_response(raw_data)
    results = []
    raw_data.map do |inv_status|

      begin
        mapped = response_mapper(inv_status, {
          'Inv_Status.Warehouse' => 'warehouse',
          'Inv_Status.ProdCode' => 'sku',
          'Inv_Status.Available' => 'quantity',
        })

        if (mapped['warehouse'] === 'Main Warehouse')
          results << mapped
        end
      rescue => error
        issue_error(AcumenAgentError.new(
          'process_inv_status_response',
          'Failed while processing Prod_Mkt record',
          { sku: get_field_value(inv_status, 'Inv_Status.ProdCode') },
          error,
        ))
      end
    end

    results
  end

  # This function maps parsed Prod_Mkt records to their matching product record
  # and updates the product object with the additional data
  def map_inv_status_data(products, inventory)
    products.map do |product|
      inventory_data = inventory.select { |i| i['sku'] == product['sku'] }
      begin

        if inventory_data
          quantity = 0
          inventory_data.each do |i|
            quantity = quantity + i['quantity'].to_i if quantity.present?
          end

          product['acumenAttributes']['stock_quantity'] = quantity
        end

      rescue => error
        issue_error(AcumenAgentError.new(
          'map_inv_status_data',
          'Failed to map inventory data for product',
          { sku: product['sku'] },
          error,
        ))
      end

      product
    end

    return products
  end
end
