# frozen_string_literal: true

# This module is responsible for reading/processing data recrods from the Inv_Product
# table in Acumen. This table contains the baseline product information -- name, sku,
# format, etc.
module InvProductQueryConcern
  extend AcumenQueryConcern

  # Fetch/Process the Acumen data,
  def fetch_inv_product_data(acumen_client, product_ids, digital_format_list)
    product_data = acumen_client.get_products(product_ids)

    return process_inv_product_response(product_data, digital_format_list)
  end

  # This function returns an array of Acumen products mapped to Schema.org/Product
  # objects. We've added additional fields of:
  #
  #     *  `isOnWebsite` -- used to control product deletion in external systems
  #     *  `acumenAttributes` -- Additional acumen data that doesn't have a direct 1:1 field
  #        on the Product, but may be useful in other platforms
  def process_inv_product_response(raw_data, digital_format_list)
    raw_data.map do |p|

      begin
        product = response_mapper(p, {
            'Inv_Product.ID' => 'identifier',
            'Inv_Product.ProdCode' => 'sku',
            'Inv_Product.Full_Title' => 'name',
            'Inv_Product.SubTitle' => 'disambiguatingDescription',
            'Inv_Product.ISBN_UPC' => 'isbn',
            'Inv_Product.Pub_Date' => 'datePublished',
            'Inv_Product.Next_Release' => 'releaseDate',
        })

        # Nullify blank dates
        if product['datePublished'] == '0000-00-00T00:00:00'
          product['datePublished'] = nil
        end

        if product['releaseDate'] == '0000-00-00T00:00:00'
          product['releaseDate'] = nil
        end

        product['@type'] = 'Product'
        product['isTaxable'] = get_field_value(p, 'Inv_Product.Taxable') == '1'
        product['isOnWebsite'] = get_field_value(p, 'Inv_Product.Not_On_Website') == '0'
        product['noBackorderFill'] = get_field_value(p, 'Inv_Product.No_Backorder_Fill') == '1'
        product['specialLink'] = get_field_value(p, 'Inv_Product.Special_Link') == '1'
        product['trackInventory'] = !(get_field_value(p, 'Inv_Product.Non_Inventory') == '1' ||
          get_field_value(p, 'Inv_Product.Assembly') == '1' ||
          get_field_value(p, 'Inv_Product.Consignment') == '1')
        product['acumenAttributes'] = {
          'info_alpha_1' => get_field_value(p, 'Inv_Product.Info_Alpha_1'),
          'info_boolean_1' => get_field_value(p, 'Inv_Product.Info_Boolean_1'), # is_available_on_formed
        }
        product['additionalProperty'] = [
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'is_master',
              'value' => get_field_value(p, 'Inv_Product.OnWeb_LinkOnly') == '0',
          },
          #  Product availability within Acumen is not always a "line in the sand"
          #  situation in some cases, the requirements can become rather complex.
          #  As a result, this agent does not strictly set availability, but rather
          #  outputs the properties associated with setting it so that client-specific
          #  logic can be implemented in subsequent agents which may require external
          #  data (such as stock quantities for consignment products).
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'disable_web_purchase',
              'value' => get_field_value(p, 'Inv_Product.Disable_Web_Purchase') == '1',
          },
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'no_backorder_fill',
              'value' => get_field_value(p, 'Inv_Product.No_Backorder_Fill') == '1',
          },
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'not_on_website',
              'value' => get_field_value(p, 'Inv_Product.Not_On_Website') == '1',
          },
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'non_inventory',
              'value' => get_field_value(p, 'Inv_Product.Non_Inventory') == '1',
          },
          {
              '@type' => 'PropertyValue',
              'propertyID' => 'is_consignment',
              'value' => get_field_value(p, 'Inv_Product.Consignment') == '1',
          },
        ]

        product['offers'] = [{
          '@type' => 'Offer',
          'price' => get_field_value(p, 'Inv_Product.Price_1'),
          'availability' => get_field_value(p, 'Inv_Product.BO_Reason')
        }]

        if get_field_value(p, 'Inv_Product.Price_2')
          product['offers'].push({
            '@type' => 'Offer',
            'price' => get_field_value(p, 'Inv_Product.Price_2'),
            'availability' => get_field_value(p, 'Inv_Product.BO_Reason')
          })
        end

        not_on_website = get_field_value(p, 'Inv_Product.Not_On_Website')
        disable_web_purchase = get_field_value(p, 'Inv_Product.Disable_Web_Purchase')

        weight = get_field_value(p, 'Inv_Product.Weight')
        product['weight'] = get_quantitative_value(weight, 'oz.')

        # The category used here is the Acumen Product category. Functionally, this
        # serves as the product's _format_. This field is different from Web Categories
        # which behave more like traditional category taxonomies.
        category = get_field_value(p, 'Inv_Product.Category')
        if category
          product['acumenAttributes']['category'] = category
          product['isDigital'] = digital_format_list.find { |f| f == category } ? true : false

          if category == 'Paperback'
            product['additionalType'] = 'Book'
            product['bookFormat'] = "http://schema.org/Paperback"
            product['accessMode'] = "textual"
          elsif category == 'Hardcover'
            product['additionalType'] = 'Book'
            product['bookFormat'] = "http://schema.org/Hardcover"
            product['accessMode'] = "textual"
          elsif category == 'eBook'
            product['additionalType'] = 'Book'
            product['bookFormat'] = "http://schema.org/EBook"
            product['accessMode'] = "textual"
          elsif category == 'CD'
            product['additionalType'] = 'CreativeWork'
            product['accessMode'] = "auditory"
          end
        end

        product

      rescue => error
        issue_error(AcumenAgentError.new(
          'process_inv_product_response',
          'Failed to load Inventory Product Records',
          {
            product_id: get_field_value(p, 'Inv_Product.ID'),
            sku: get_field_value(p, 'Inv_Product.ProdCode')
          },
          error,
        ))

        return
      end
    end
  end
end
