# frozen_string_literal: true

module Agents
    class AcumenProductAgent < Agent
        include WebRequestConcern
        include AcumenProductQueryConcern

        default_schedule '12h'

        can_dry_run!
        default_schedule 'never'

        description <<-MD
      Huginn agent for sane ACUMEN product data.
        MD

        def default_options
            {
                'endpoint' => 'https://example.com',
                'site_code' => '',
                'password' => '',
                'attribute_to_property' => {},
                'contributor_types_map' => {},
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

            unless options['attribute_to_property'].is_a?(Hash)
                errors.add(:base, "if provided, attribute_to_property must be a hash")
            end

            unless options['contributor_types_map'].is_a?(Hash)
                errors.add(:base, "if provided, contributor_types_map must be a hash")
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

            auth = {
                'site_code' => site_code,
                'password' => password,
                'endpoint' => endpoint,
            }
            client = AcumenClient.new(faraday, auth)

            ids = event.payload['ids']
            products = get_products_by_ids(client, ids)
            products = get_product_variants(client, products)
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
                create_event payload: product
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
