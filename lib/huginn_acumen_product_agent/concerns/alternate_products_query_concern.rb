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

  # Fetches the Inv_Product.ID for alternate formats of the provided product_ids
  def fetch_alternate_format_ids(acumen_client, product_ids)
    begin
      link_data = acumen_client.get_linked_products(product_ids)

      links = process_alternate_format_response(link_data)

      return map_alternate_format_links(links, product_ids)
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
