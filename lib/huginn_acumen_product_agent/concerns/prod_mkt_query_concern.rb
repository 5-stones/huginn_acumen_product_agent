# frozen_string_literal: true

# This module is responsible for reading/processing the ProdMkt table. This table
# contains more detailed product meta information: Publisher, page counts, age range,
# description, etc.
module ProdMktQueryConcern
  extend AcumenQueryConcern

  # Update the provided products with their associated marketing data
  # NOTE: The `products` here are Shema.org/Product records mapped from Inv_Product
  # data
  def fetch_product_marketing(acumen_client, products)

    product_ids = products.map { |p| p['identifier'] }
    marketing_data = acumen_client.get_products_marketing(product_ids)
    marketing_data = process_prod_mkt_response(marketing_data)

    return map_marketing_data(products, marketing_data)
  end

  # This function parses the raw data returned from the Prod_Mkt table
  def process_prod_mkt_response(raw_data)
    results = {}
    raw_data.map do |product_marketing|

      begin
        mapped = response_mapper(product_marketing, {
          'ProdMkt.Product_ID' => 'product_id',
          'ProdMkt.Product_Code' => 'sku',
          'ProdMkt.ID' => 'id',
          'ProdMkt.Pages' => 'pages',
          'ProdMkt.Publisher' => 'publisher',
          'ProdMkt.Description_Short' => 'description_short',
          'ProdMkt.Description_Long' => 'description_long',
          'ProdMkt.Height' => 'height',
          'ProdMkt.Width' => 'width',
          'ProdMkt.Thickness' => 'thickness',
          'ProdMkt.Meta_Keywords' => 'meta_keywords',
          'ProdMkt.Meta_Description' => 'meta_description',
          'ProdMkt.Extent_Unit' => 'extent_unit',
          'ProdMkt.Extent_Value' => 'extent_value',
          'ProdMkt.Age_Highest' => 'age_highest',
          'ProdMkt.Age_Lowest' => 'age_lowest',
          'ProdMkt.Awards' => 'awards',
          'ProdMkt.Dimensions_Unit_Measure' => 'dimensions_unit_measure',
          'ProdMkt.Excerpt' => 'excerpt',
          'ProdMkt.Grade_Highest' => 'grade_highest',
          'ProdMkt.Grade_Lowest' => 'grade_lowest',
          'ProdMkt.Status' => 'status',
          'ProdMkt.UPC' => 'upc',
          'ProdMkt.Weight_Unit_Measure' => 'weight_unit_measure',
          'ProdMkt.Weight' => 'weight',
          'ProdMkt.Info_Text_01' => 'info_text_01',
          'ProdMkt.Info_Text_02' => 'info_text_02',
          'ProdMkt.Religious_Text_Identifier' => 'religious_text_identifier',
          'ProdMkt.Info_Alpha_07' => 'info_alpha_07',
        })

        results[mapped['product_id']] = mapped
        # NOTE: In this case, product_id matches the Inv_Product.ID fields
      rescue => error
        issue_error(AcumenAgentError.new(
          'process_prod_mkt_response',
          'Failed while processing Prod_Mkt record',
          { sku: get_field_value(product_marketing, 'ProdMkt.Product_Code') },
          error,
        ))
      end
    end

    results
  end

  # This function maps parsed Prod_Mkt records to their matching product record
  # and updates the product object with the additional data
  def map_marketing_data(products, marketing_data)
    products.map do |product|
      marketing = marketing_data[product['identifier']]

      begin

        if marketing
          product['acumenAttributes']['product_marketing_id'] = marketing['id']

          product['publisher'] = {
            '@type': 'Organization',
            'name' => marketing['publisher']
          };
          product['description'] = marketing['description_long']
          product['abstract'] = marketing['description_short']
          product['keywords'] = marketing['meta_keywords']
          product['text'] = marketing['excerpt']

          if marketing['age_lowest'] && marketing['age_highest']
            product['typicalAgeRange'] = "#{marketing['age_lowest']}-#{marketing['age_highest']}"
          end

          #----------  Product Page Attributes  ----------#
          if marketing['grade_lowest'] || marketing['grade_highest']
            # educationalUse? educationalAlignment?
            product['additionalProperty'].push({
              '@type' => 'PropertyValue',
              'name' => 'Grade',
              'propertyID' => 'grade_range',
              'minValue' => marketing['grade_lowest'],
              'maxValue' => marketing['grade_highest'],
              'value' => "#{marketing['grade_lowest']}-#{marketing['grade_highest']}",
            })
          end

          if marketing['awards']
            product['additionalProperty'].push({
              '@type' => 'PropertyValue',
              'propertyID' => 'awards',
              'name' => 'Awards',
              'value' => marketing['awards'],
            })
          end

          #----------  Acumen Specific Properties  ----------#
          product['acumenAttributes']['extent_unit'] = marketing['extent_unit']
          product['acumenAttributes']['extent_value'] = marketing['extent_value']
          product['acumenAttributes']['info_text_01'] = marketing['info_text_01'] # editorial_reviews
          product['acumenAttributes']['info_text_02'] = marketing['info_text_02'] # product_samples
          product['acumenAttributes']['info_alpha_07'] = marketing['info_alpha_07'] # video_urls
          product['acumenAttributes']['meta_description'] = marketing['meta_description']
          product['acumenAttributes']['religious_text_identifier'] = marketing['religious_text_identifier']
          product['acumenAttributes']['status'] = marketing['status']

          product['gtin12'] = marketing['upc']
          product['numberOfPages'] = marketing['pages']

          product['height'] = get_quantitative_value(
            marketing['height'], marketing['dimensions_unit_measure']
          )
          product['width'] = get_quantitative_value(
            marketing['width'], marketing['dimensions_unit_measure']
          )
          product['depth'] = get_quantitative_value(
            marketing['thickness'], marketing['dimensions_unit_measure']
          )
          if product['weight']['value'] == '0'
              product['weight'] = get_quantitative_value(
                marketing['weight'], marketing['weight_unit_measure']
              )
          end
        end

      rescue => error
        issue_error(AcumenAgentError.new(
          'map_marketing_data',
          'Failed to map marketing data for product',
          { id: product['identifier'], sku: marketing['sku'] },
          error,
        ))
      end

      product
    end

    return products
  end
end
