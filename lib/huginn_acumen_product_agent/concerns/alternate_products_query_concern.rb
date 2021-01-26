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

      links = process_alternate_format_response(link_data)

      mapped_ids = map_alternate_format_links(links, product_ids)

      id_set = [] + product_ids
      mapped_ids.each_value { |bundle| id_set += bundle }

      return {id_set: id_set, alternate_ids_map: mapped_ids }
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
  def process_alternate_format_response(raw_data)
    results = []
    raw_data.map do |link|

      begin
        mapped = response_mapper(link, {
          'Product_Link.Link_From_ID' => 'from_id',
          'Product_Link.Link_To_ID' => 'to_id',
          'Product_Link.Alt_Format' => 'alt_format',
        })

        if mapped['alt_format'].to_s != '0' && !mapped.in?(results)
          results.push(mapped)
        end

      rescue => error
        issue_error(AcumenAgentError.new(
          'process_alternate_format_response',
          'Failed while processing alternate format links',
          raw_data,
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
