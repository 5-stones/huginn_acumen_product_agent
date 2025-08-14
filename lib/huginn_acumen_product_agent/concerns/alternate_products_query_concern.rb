# frozen_string_literal: true

# This module is responsible for reading/processing data from the Product_Link
# table. This table defines the link between product records.
#
# It's important to note that this table defines links between related products
# as well as product formats. The `Alt_Format` field determines whether the linked
# product is an alternate format for a given title.
#
# For the purposes of this concern, we only care about Product_Link records where
# the `Alt_Format` field is `true`
module AlternateProductsQueryConcern
  extend AcumenQueryConcern

  # This function returns two data elements in a hash object.
  # The `id_set` is the full collection of IDs to be fetched including the input
  # product_ids and all of their alternate format ids. The goal of this value
  # is to reduce the resource requirements of running each "bundle" individually
  #
  # The alternate_ids_map contains arrays of product IDs mapped to their master
  # product id. This map will be used to assemble fetched product data into bundles
  def fetch_alternate_format_ids(acumen_client, product_ids)
    begin
      link_data = acumen_client.get_linked_products(product_ids)

      links = process_linked_products_response(link_data)
      alternate_formats = links[:alternate_formats]
      related_products = links[:related_products]

      alternate_ids_map = map_alternate_format_links(alternate_formats, product_ids)
      related_ids_map = map_alternate_format_links(related_products, product_ids)

      id_set = [] + product_ids
      alternate_ids_map.each_value { |bundle| id_set += bundle }

      return {
        id_set: id_set,
        alternate_ids_map: alternate_ids_map,
        related_ids_map: related_ids_map,
      }
    rescue => error
      issue_error(AcumenAgentError.new(
        'fetch_alternate_format_ids',
        'Failed attempting to lookup alternate products',
        product_ids,
        error
      ))
    end
  end

  # This function parses the raw data returned from the Product_Link table
  # The resulting array contains the set alternate format IDs associated with a
  # single product
  def process_linked_products_response(raw_data)
    results = {
      alternate_formats: [],
      related_products: [],
    }

    raw_data.each do |link|
      begin
        mapped = response_mapper(link, {
          'Product_Link.Link_From_ID' => 'from_id',
          'Product_Link.Link_To_ID' => 'to_id',
          'Product_Link.Alt_Format' => 'alt_format',
          'Product_Link.Inactive' => 'inactive',
        })

        if mapped['inactive'] == '0'
          next
        end

        if mapped['alt_format'].to_s != '0' && !mapped.in?(results[:alternate_formats])
          results[:alternate_formats].push(mapped)
        elsif !mapped.in?(results[:related_products])
          results[:related_products].push(mapped)
        end

      rescue => error
        issue_error(AcumenAgentError.new(
          'process_linked_products_response',
          'Failed while processing alternate format links',
          { product_id: get_field_value(link, 'Product_Link.Link_From_ID') },
          error
        ))
      end
    end

    return results
  end

  # Returns a map that ties each provided `product_id` to an array of IDs for its
  # other formats
  def map_alternate_format_links(links, product_ids)
    results = {}

    product_ids.each do |id|
      begin
        alternates = links.select { |l| l['from_id'] == id }
        results[id] = alternates.map { |l| l['to_id'] }

      rescue => error
        issue_error(AcumenAgentError.new(
          'map_alternate_format_links',
          'Failed while mapping alternate format links',
          { id: id, links: links },
          error
        ))
      end
    end

    return results
  end
end
