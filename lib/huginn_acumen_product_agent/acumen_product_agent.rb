# frozen_string_literal: true

module Agents
    class AcumenProductAgent < Agent
        include WebRequestConcern
        include AcumenQueryConcern
        include InvProductQueryConcern
        include ProdMktQueryConcern
        include ProductContributorsQueryConcern
        include ProductCategoriesQueryConcern
        include AlternateProductsQueryConcern

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

        ### Format Options
        * digital_formats: A list of the formats associated with a digital product

        ### Product Attributes
        * attribute_to_property: An optional map linking Acumen attributes to Schema.org
          product properties.

        ### Other Options
        * ignore_skus: An optional array of Acumen product skus that will be intentionally
          excluded from any output.

        ### Event Output
        This agent will output one of two event types during processing:

        *  Product bundles
        *  Processing Errors

        The product bundle payload will be structured as:

        ```
        {
          products: [ { ... }, { ... }, ... ],
          status: 200
        }
        ```

        The processing error payload will be structured as:

        ```
        {
          status: 500,
          scope: '[Process Name]',
          message: '[Error Message]',
          data: { ... },
          trace: [ ... ]
        }
        ```

        ### Payload Status

        `status: 200`: Indicates a true success. The agent has output the full
        range of expected data.

        `status: 206`: Indicates a partial success. The products within the bundle
        are vaild, but the bundle _may_ be missing products that were somehow invalid.

        `status: 500`: Indicates a processing error. This may represent a complete
        process failure, but may also be issued in parallel to a `202` payload.

        Because this agent receives an array of Product IDs as input, errors will be issued in
        such a way that product processing can recover when possible. Errors that occur within
        a specific product bundle will emit an error event, but the agent will then move
        forward processing the next bundle.

        For example, if this agent receives two products as input (`A` and `B`), and we fail to
        load the Inv_Product record for product `A`, the agent would emit an error payload of:

        ```
        {
          status: 500,
          scope: 'Fetch Inv_Product Data',
          message: 'Failed to lookup Inv_Product record for Product A',
          data: { product_id: 123 },
          trace: [ ... ]
        }
        ```

        The goal of this approach is to ensure the agent outputs as much data as reasonably possible
        with each execution. If there is an error in the Paperback version of a title, that shouldn't
        prevent this agent from returning the Hardcover version.

        MD

        def default_options
            {
                'endpoint' => 'https://example.com',
                'site_code' => '',
                'password' => '',
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
            # Process agent options
            endpoint = interpolated['endpoint']
            site_code = interpolated['site_code']
            password = interpolated['password']
            digital_formats = interpolated['digital_formats']
            ignored_skus = interpolated['ignore_skus'] ? interpolated['ignore_skus'] : []

            # Configure the Acumen Client
            auth = {
                'site_code' => site_code,
                'password' => password,
                'endpoint' => endpoint,
            }
            client = AcumenClient.new(faraday, auth)

            ids = event.payload['ids']

            # Load Products
            fetch_product_bundles(client, ids, digital_formats, ignored_skus)
        end

        private

        # Returns an array of Product objects for the provided product_ids.
        # Each object is a merged representation of all the individual Acumen tables
        # that make up a product record with fields mapped to the schema.org/Product
        # object definition.
        def fetch_products(acumen_client, product_ids, digital_format_list)
            products = fetch_inv_product_data(acumen_client, product_ids, digital_format_list)
            products = fetch_product_marketing(acumen_client, products)
            products = fetch_inv_status(acumen_client, products)
            products = fetch_product_contributors(acumen_client, products)
            products = fetch_product_categories(acumen_client, products)

            products.each do |product|
                map_attributes(product)
            end

            return products
        end

        # Loads product bundles for the provided `product_ids` array and emits
        # a unique event payload for each bundle. Emitted events will contain an
        # array of all the product definitions for each format of a given title.
        #
        # NOTE: The generated bundles will contain both active and inactive products
        # to facilitate product deletion in external systems.
        def fetch_product_bundles(acumen_client, product_ids, digital_format_list, ignored_skus)

          begin
            data = fetch_alternate_format_ids(acumen_client, product_ids)
            full_id_set = data[:id_set]
            alternate_ids_map = data[:alternate_ids_map]
            product_data = fetch_products(acumen_client, full_id_set, digital_format_list)

            bundles = product_ids.map do |id|
              bundle_ids = alternate_ids_map[id]
              bundle_ids.append(id) unless bundle_ids.include?(id)
              bundle_ids.sort()

              bundle = []
              bundle_ids.each() do |b_id|
                # Filter out any products that are explicitly ignored by SKU
                product = product_data.find { |p| p['identifier'] == b_id.to_s }
                bundle << product unless product.nil? || ignored_skus.include?(product['sku'])
                # NOTE: The product.nil? check is designed to handle cases where a product link
                # points to a non existent product. Conventionally this shouldn't happen, but
                # we've seen it, and need to account for it.
              end

              create_event payload: { products: bundle, status: 200 }
            end
          rescue AcumenAgentError => e
            issue_error(e)
          end
        end

        # Maps additional Acumen attributes to the `additionalProperty` array
        # NOTE:  Attributes mapped in this way will be _removed_ from the
        # `acumenAttributes` array.
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
