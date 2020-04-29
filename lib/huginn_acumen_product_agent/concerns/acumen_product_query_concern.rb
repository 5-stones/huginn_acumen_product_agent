# frozen_string_literal: true

module AcumenProductQueryConcern
    extend ActiveSupport::Concern

    UNIT_MAP = {
      'oz.' => 'OZ',
      'Inches (US)' => 'INH',
    }

    def get_products_by_ids(acumen_client, ids)
        response = acumen_client.get_products(ids)
        products = parse_product_request(response)

        response = acumen_client.get_products_marketing(ids)
        marketing = parse_product_marketing_request(response)

        merge_products_and_marketing(products, marketing)
    end

    def get_variants_for_ids(acumen_client, ids)
        result = get_linked_products_by_ids(acumen_client, ids)
        result.select { |link| link['alt_format'].to_s != 0.to_s }
    end

    def get_linked_products_by_ids(acumen_client, ids)
        response = acumen_client.get_linked_products(ids)
        process_linked_product_query(response)
    end

    def get_product_contributors(acumen_client, products)
        ids = products.map {|product| product['acumenAttributes']['product_marketing_id']}
        response = acumen_client.get_product_contributors(ids)
        product_contributors = process_product_contributor_query(response)

        products.each do |product|
            id = product['acumenAttributes']['product_marketing_id']
            product_contributor = product_contributors[id]


            if product_contributor
                contributor_ids = product_contributor.map do |pc|
                  pc['contributor_id']
                end

                type_response = acumen_client.get_contributor_types(contributor_ids)
                contributor_types = process_contributor_types_query(type_response)

                product['contributors'] = product_contributor.map do |pc|
                    {
                        '@type' => 'Person',
                        'identifier' => pc['contributor_id'],
                        'acumenAttributes' => {
                            'contrib_type' => contributor_types[pc['contributor_id']]
                        }
                    }
                end
            end
        end
        products
    end

    def get_product_variants(acumen_client, products, physical_formats, digital_formats)
        ids = products.map { |product| product['identifier'] }
        # fetch product/variant relationships
        variant_links = get_variants_for_ids(acumen_client, ids)
        variant_ids = variant_links.map { |link| link['to_id'] }

        variant_ids = variant_links.map { |link| link['to_id'] }

        # fetch product variants
        variants = get_products_by_ids(acumen_client, variant_ids)

        # merge variants and products together
        process_products_and_variants(products, variants, variant_links, physical_formats, digital_formats)
    end

    def get_product_categories(acumen_client, products)
        # fetch categories
        skus = products.map { |product| product['sku'] }
        response = acumen_client.get_product_categories(skus)
        categories = process_product_categories_query(response)

        # map categories to products
        products.each do |product|
            sku = product['sku']
            if categories[sku]
                active = categories[sku].select { |c| c['inactive'] == '0' }
                product['categories'] = active.map do |category|
                  {
                    '@type' => 'Thing',
                    'identifier' => category['category_id']
                  }
                end
            end
        end

        products
    end

    def parse_product_request(products)
        products.map do |p|
            variant = response_mapper(p, {
                'Inv_Product.ID' => 'identifier',
                'Inv_Product.ProdCode' => 'sku',
                'Inv_Product.SubTitle' => 'disambiguatingDescription',
                'Inv_Product.ISBN_UPC' => 'isbn',
                'Inv_Product.Pub_Date' => 'datePublished',
            })
            variant['@type'] = 'ProductModel'
            variant['isDefault'] = false
            variant['isTaxable'] = field_value(p, 'Inv_Product.Taxable') == '1'
            variant['acumenAttributes'] = {
              'is_master' => field_value(p, 'Inv_Product.OnWeb_LinkOnly') == '0'
            }

            variant['offers'] = [{
                '@type' => 'Offer',
                'price' => field_value(p, 'Inv_Product.Price_1'),
            }]
            if field_value(p, 'Inv_Product.Price_2')
              variant['offers'].push({
                  '@type' => 'Offer',
                  'price' => field_value(p, 'Inv_Product.Price_2'),
              })
            end

            weight = field_value(p, 'Inv_Product.Weight')
            variant['weight'] = quantitative_value(weight, 'oz.')

            product = {
                '@type' => 'Product',
                'identifier' => variant['identifier'],
                'sku' => variant['sku'],
                'name' => field_value(p, 'Inv_Product.Full_Title'),
                'disambiguatingDescription' => field_value(p, 'Inv_Product.SubTitle'),
                'model' => [
                    variant
                ],
                'additionalProperty' => [],
                'acumenAttributes' => {
                    'info_alpha_1' => field_value(p, 'Inv_Product.Info_Alpha_1'),
                    'info_boolean_1' => field_value(p, 'Inv_Product.Info_Boolean_1'),
                },
            }

            category = field_value(p, 'Inv_Product.Category')
            if category

              if variant['acumenAttributes']
                variant['acumenAttributes']['category'] = category
              else
                 variant['acumenAttributes'] = { 'category' => category }
              end

              if category == 'Paperback'
                product['additionalType'] = variant['additionalType'] = 'Book'
                variant['bookFormat'] = "http://schema.org/Paperback"
                variant['accessMode'] = "textual"
                variant['isDigital'] = false
              elsif category == 'Hardcover'
                product['additionalType'] = variant['additionalType'] = 'Book'
                variant['bookFormat'] = "http://schema.org/Hardcover"
                variant['accessMode'] = "textual"
                variant['isDigital'] = false
              elsif category == 'eBook'
                product['additionalType'] = variant['additionalType'] = 'Book'
                variant['bookFormat'] = "http://schema.org/EBook"
                variant['accessMode'] = "textual"
                variant['isDigital'] = true
              elsif category == 'CD'
                product['additionalType'] = variant['additionalType'] = 'CreativeWork'
                variant['accessMode'] = "auditory"
                variant['isDigital'] = false
              else
                variant['isDigital'] = false
              end
            end

            product
        end
    end

    def process_linked_product_query(links)
        links.map do |link|
            response_mapper(link, {
                'Product_Link.Link_From_ID' => 'from_id',
                'Product_Link.Link_To_ID' => 'to_id',
                'Product_Link.Alt_Format' => 'alt_format',
            })
        end
    end

    def parse_product_marketing_request(products)
        results = {}
        products.each do |product|
            mapped = response_mapper(product, {
                'ProdMkt.Product_ID' => 'product_id',
                'ProdMkt.Product_Code' => 'sku',
                'ProdMkt.ID' => 'id',
                'ProdMkt.Pages' => 'pages',
                'ProdMkt.Publisher' => 'publisher',
                'ProdMkt.Description_Short' => 'description_short',
                'ProdMkt.Description_Long' => 'description_long',
                'ProdMkt.Height' => 'height',
                'ProdMkt.Width' => 'width',
                'ProdMkt.Thickness' => 'depth',
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
            })

            results[mapped['product_id']] = mapped
        end

        results
    end

    def merge_products_and_marketing(products, product_marketing)
        products.each do |product|
            marketing = product_marketing[product['identifier']]
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

                if marketing['age_lowest'] || marketing['age_highest']
                    product['typicalAgeRange'] = "#{marketing['age_lowest']}-#{marketing['age_highest']}"
                end

                # properties for product pages
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

                # acumen specific properties
                product['acumenAttributes']['extent_unit'] = marketing['extent_unit']
                product['acumenAttributes']['extent_value'] = marketing['extent_value']
                product['acumenAttributes']['info_text_01'] = marketing['info_text_01']
                product['acumenAttributes']['info_text_02'] = marketing['info_text_02']
                product['acumenAttributes']['meta_description'] = marketing['meta_description']
                product['acumenAttributes']['religious_text_identifier'] = marketing['religious_text_identifier']
                product['acumenAttributes']['status'] = marketing['status']

                variant = product['model'][0]
                variant['gtin12'] = marketing['upc']
                variant['numberOfPages'] = marketing['pages']

                variant['height'] = quantitative_value(
                  marketing['height'], marketing['dimensions_unit_measure']
                )
                variant['width'] = quantitative_value(
                  marketing['width'], marketing['dimensions_unit_measure']
                )
                variant['depth'] = quantitative_value(
                  marketing['thickness'], marketing['dimensions_unit_measure']
                )
                variant['weight'] = quantitative_value(
                  marketing['weight'], marketing['weight_unit_measure']
                )
            end
        end

        products
    end

    def process_product_categories_query(categories)
        results = {}
        categories.each do |category|
            mapped = response_mapper(category, {
                'ProdMkt_WPC.ProdCode' => 'sku',
                'ProdMkt_WPC.WPC_ID' => 'category_id',
                'ProdMkt_WPC.Inactive' => 'inactive',
            })

            if results[mapped['sku']]
                results[mapped['sku']].push(mapped)
            else
                results[mapped['sku']] = [mapped]
            end
        end

        results
    end

    def process_product_contributor_query(contributors)
        results = {}
        contributors.each do |contributor|
            mapped = response_mapper(contributor, {
                'ProdMkt_Contrib_Link.ProdMkt_Contrib_ID' => 'contributor_id',
                'ProdMkt_Contrib_Link.ProdMkt_ID' => 'product_marketing_id',
                'ProdMkt_Contrib_Link.Inactive' => 'inactive',
            })

            if mapped['inactive'] == '0'

              if results[mapped['product_marketing_id']]
                  results[mapped['product_marketing_id']].push(mapped)
              else
                  results[mapped['product_marketing_id']] = [mapped]
              end
            end
        end
        results
    end

    def process_contributor_types_query(types)
      results = {}
      types.each do |type|
          mapped = response_mapper(type, {
              'ProdMkt_Contributor.ID' => 'contributor_id',
              'ProdMkt_Contributor.Contrib_Type' => 'type',
          })

          if !results[mapped['contributor_id']]
              results[mapped['contributor_id']] = mapped['type']
          end
      end

      results
    end

    def process_products_and_variants(products, variants, links, physical_formats, digital_formats)
        products_map = {}
        products.each { |product| products_map[product['identifier']] = product }

        variants_map = {}
        variants.each { |variant| variants_map[variant['identifier']] = variant }

        links.each do |link|
            from_id = link['from_id']
            to_id = link['to_id']
            variant = variants_map[to_id]
            variant['isDefault'] = false
            products_map[from_id]['model'].push(*variant['model'])
        end

        result = []
        products_map.each_value { |p| result.push(p) }

        result.each do |product|
          if product['model'].length == 1
            product['model'][0]['isDefault'] = true
            next
          else
            physical_formats.each do |val|
              match = product['model'].select { |v| v['acumenAttributes']['category'] == val }

              if match && match.length > 0
                match[0]['isDefault'] = true
                break
              end
            end

            digital_formats.each do |val|
              match = product['model'].select { |v| v['acumenAttributes']['category'] == val }

              if match && match.length > 0
                match[0]['isDefault'] = true
                break
              end
            end
          end
        end
        result
    end

    private

    def response_mapper(data, map)
        result = {}
        map.each do |key,val|
            result[val] = field_value(data, key)
        end

        result
    end

    def field_value(field, key)
        field[key]['__content__'] if field[key]
    end

    def quantitative_value(value, unit)
      {
        '@type' => 'QuantitativeValue',
        'value' => value,
        'unitText' => unit,
        'unitCode' => (UNIT_MAP[unit] if unit),
      } if value
    end
end
