# frozen_string_literal: true

module Agents
    class AcumenProductAgent < Agent
        include WebRequestConcern
        include AcumenProductQueryConcern

        default_schedule '12h'

        can_dry_run!
        default_schedule 'never'

        description <<-MD
      Huginn agent for retrieving sane ACUMEN product data.

      ## Agent Options
      The following outlines the available options in this agent

      ### Acumen Connection
      * endpoint: The root URL for the Acumen API
      * site_code: The site code from Acumen
      * password: The Acumen API password

      ### Variant Settings
      * physical_formats: A list of the formats associated with a physical product
      * digital_formats: A list of the formats associated with a digital product

      ### Product Attributes
      * attribute_to_property: An optional map linking Acumen attributes to Schema.org
        product properties.

      ### Other Options
      * ignore_skus: An optional array of Acumen product skus that will be intentionally
        excluded from any output.

        MD

        def default_options
            {
                'endpoint' => 'https://example.com',
                'site_code' => '',
                'password' => '',
                'physical_formats' => [],
                'digital_formats' => [],
                'attribute_to_property' => {},
            }
        end

        def validate_options
            unless options['endpoint'].present?
                errors.add(:base, 'endpoint is a required field')
            end

            unless options['site_code'].present?
                errors.add(:base, 'site_code is a required field')
            end

            unless options['password'].present?
                errors.add(:base, 'password is a required field')
            end

            unless options['physical_formats'].present?
                errors.add(:base, "physical_formats is a required field")
            end

            unless options['digital_formats'].present?
                errors.add(:base, "digital_formats is a required field")
            end

            unless options['attribute_to_property'].is_a?(Hash)
                errors.add(:base, "if provided, attribute_to_property must be a hash")
            end

            if options['ignore_skus']
              unless options['ignore_skus'].is_a?(Array)
                  errors.add(:base, "if provided, ignore_skus must be an array")
              end
            end
        end

        def working?
            received_event_without_error?
        end

        def check
            handle interpolated['payload'].presence || {}
        end

        def receive(incoming_events)
            incoming_events.each do |event|
                handle(event)
            end
       end

        private

        def handle(event)
            endpoint = interpolated['endpoint']
            site_code = interpolated['site_code']
            password = interpolated['password']
            physical_formats = interpolated['physical_formats']
            digital_formats = interpolated['digital_formats']
            ignore_skus = interpolated['ignore_skus'] ? interpolated['ignore_skus'] : []

            auth = {
                'site_code' => site_code,
                'password' => password,
                'endpoint' => endpoint,
            }
            client = AcumenClient.new(faraday, auth)

            ids = event.payload['ids']
            products = get_products_by_ids(client, ids)
            products = get_product_variants(client, products, physical_formats, digital_formats)
            products = get_master_products_by_id(client, products)
            products = get_product_categories(client, products)
            products = get_product_contributors(client, products)

            # map attributes
            products.map do |product|
                map_attributes(product)

                product['model'].each do |model|
                    map_attributes(model)
                end

                product
            end

            products.each do |product|
                unless ignore_skus.include?(product['sku'])
                  create_event payload: product
                end
            end
        end

        private

        def map_attributes(product)
            attribute_to_property = interpolated['attribute_to_property']
            attributes = product['acumenAttributes']

            attributes.each do |key,val|
                if attribute_to_property[key] && val
                    product['additionalProperty'] = [] if product['additionalProperty'].nil?
                    product['additionalProperty'].push({
                        '@type' => 'PropertyValue',
                        'propertyID' => attribute_to_property[key],
                        'value' => val,
                    })

                    attributes.delete(key)
                end
            end
        end
    end
end
