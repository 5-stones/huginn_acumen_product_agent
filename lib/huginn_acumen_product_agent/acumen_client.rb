class AcumenClient
  @faraday
  @auth

  def initialize(faraday, auth)
    @faraday = faraday
    @auth = auth
  end

  def get_products(ids)
      body = build_product_request(ids)
      response = execute_in_list_query(body, {})
      get_results(response, 'Inv_Product')
  end

  def get_products_marketing(ids)
      body = build_product_marketing_query(ids)
      response = execute_in_list_query(body, {})
      get_results(response, 'ProdMkt')
  end

  def get_linked_products(ids)
      body = build_linked_product_query(ids)
      response = execute_in_list_query(body, {})
      get_results(response, 'Product_Link')
  end

  def get_product_contributors(ids)
      body = build_product_contributor_link_query(ids)
      response = execute_in_list_query(body, {})
      get_results(response, 'ProdMkt_Contrib_Link')
  end

  def get_product_categories(skus)
      q = build_product_categories_query(skus)
      response = execute_in_list_query(q, {})
      get_results(response, 'ProdMkt_WPC')
  end


  def execute_query(body, headers)
      response = @faraday.run_request(:post, "#{@auth['endpoint']}/Query", body, headers)
      ::MultiXml.parse(response.body, {})
  end

  def execute_in_list_query(body, headers)
      response = @faraday.run_request(:post, "#{@auth['endpoint']}/QueryByInList", body, headers)
      ::MultiXml.parse(response.body, {})
  end

  def get_results(response, name)
      result_set = response['Envelope']['Body']['acusoapResponse']['result_set.' + name]
      results = result_set.nil? ? [] : result_set[name]
      results.is_a?(Array) ? results : [results]
  end

  private

  def build_product_request(ids)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>Inv_Product.ID</column_name>
                  <comparator>in</comparator>
                  <value>#{ids.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                  <view_owner_table_name>Inv_Product</view_owner_table_name>
                  <view_name>Inv_ProductAllRead</view_name>
                  <column_name>Inv_Product.ID</column_name>
                  <column_name>Inv_Product.ProdCode</column_name>
                  <column_name>Inv_Product.Title</column_name>
                  <column_name>Inv_Product.Full_Title</column_name>
                  <column_name>Inv_Product.SubTitle</column_name>
                  <column_name>Inv_Product.ISBN_UPC</column_name>
                  <column_name>Inv_Product.Price_1</column_name>
                  <column_name>Inv_Product.Price_2</column_name>
                  <column_name>Inv_Product.Weight</column_name>
                  <column_name>Inv_Product.Taxable</column_name>
                  <column_name>Inv_Product.Pub_Date</column_name>
                  <column_name>Inv_Product.DateTimeStamp</column_name>
                  <column_name>Inv_Product.OnWeb_LinkOnly</column_name>
                  <column_name>Inv_Product.Download_Product</column_name>
                  <column_name>Inv_Product.Info_Alpha_1</column_name>
                  <column_name>Inv_Product.Info_Boolean_1</column_name>>
                  <column_name>Inv_Product.Category</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_product_marketing_query(ids)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>ProdMkt.Product_ID</column_name>
                  <comparator>in</comparator>
                  <value>#{ids.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                <view_owner_table_name>ProdMkt</view_owner_table_name>
                <view_name>ProdMktAllRead</view_name>
                  <column_name>ProdMkt.Product_ID</column_name>
                  <column_name>ProdMkt.Product_Code</column_name>
                  <column_name>ProdMkt.ID</column_name>
                  <column_name>ProdMkt.DateTimeStamp</column_name>
                  <column_name>ProdMkt.Pages</column_name>
                  <column_name>ProdMkt.Publisher</column_name>
                  <column_name>ProdMkt.Description_Short</column_name>
                  <column_name>ProdMkt.Description_Long</column_name>
                  <column_name>ProdMkt.Height</column_name>
                  <column_name>ProdMkt.Width</column_name>
                  <column_name>ProdMkt.Thickness</column_name>
                  <column_name>ProdMkt.Meta_Keywords</column_name>
                  <column_name>ProdMkt.Meta_Description</column_name>
                  <column_name>ProdMkt.Extent_Unit</column_name>
                  <column_name>ProdMkt.Extent_Value</column_name>
                  <column_name>ProdMkt.Age_Highest</column_name>
                  <column_name>ProdMkt.Age_Lowest</column_name>
                  <column_name>ProdMkt.Awards</column_name>
                  <column_name>ProdMkt.Dimensions_Unit_Measure</column_name>
                  <column_name>ProdMkt.Excerpt</column_name>
                  <column_name>ProdMkt.Grade_Highest</column_name>
                  <column_name>ProdMkt.Grade_Lowest</column_name>
                  <column_name>ProdMkt.Status</column_name>
                  <column_name>ProdMkt.UPC</column_name>
                  <column_name>ProdMkt.Weight_Unit_Measure</column_name>
                  <column_name>ProdMkt.Weight</column_name>
                  <column_name>ProdMkt.Info_Text_01</column_name>
                  <column_name>ProdMkt.Info_Text_02</column_name>
                  <column_name>ProdMkt.Religious_Text_Identifier</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_product_ids_since_request(since)
      <<~XML
          <acusoapRequest>
            #{build_acumen_query_auth()}
            <query>
              <statement>
                <column_name>Inv_Product.Not_Active</column_name>
                <comparator>equals</comparator>
                <value>false</value>
                <conjunction>and</conjunction>
              </statement>
              <statement>
                <column_name>Inv_Product.Not_On_Website</column_name>
                <comparator>equals</comparator>
                <value>false</value>
                <conjunction>and</conjunction>
              </statement>
              <statement>
                <column_name>Inv_Product.DateTimeStamp</column_name>
                <comparator>greater than</comparator>
                <value>#{since}</value>
                <conjunction>and</conjunction>
              </statement>
              <statement>
                <column_name>Inv_Product.OnWeb_LinkOnly</column_name>
                <comparator>equals</comparator>
                <value>false</value>
                <conjunction>and</conjunction>
              </statement>
            </query>
            <requested_output>
              <view_owner_table_name>Inv_Product</view_owner_table_name>
              <view_name>Inv_ProductAllRead</view_name>
              <column_name>Inv_Product.ID</column_name>
            </requested_output>
          </acusoapRequest>
      XML
  end

  def build_linked_product_query(ids)
      <<~XML
          <acusoapRequest>
            #{build_acumen_query_auth()}
            <query>
              <statement>
                <column_name>Product_Link.Link_From_ID</column_name>
                <comparator>in</comparator>
                <value>#{ids.join(',')}</value>
              </statement>
            </query>
            <requested_output>
              <view_owner_table_name>Product_Link</view_owner_table_name>
              <view_name>Product_LinkAllRead</view_name>
              <column_name>Product_Link.Link_From_ID</column_name>
              <column_name>Product_Link.Link_To_ID</column_name>
              <column_name>Product_Link.Alt_Format</column_name>
            </requested_output>
          </acusoapRequest>
      XML
  end

  def build_product_categories_query(ids)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>ProdMkt_WPC.ProdCode</column_name>
                  <comparator>in</comparator>
                  <value>#{ids.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                <view_owner_table_name>ProdMkt_WPC</view_owner_table_name>
                <view_name>ProdMkt_WPCAllRead</view_name>
                <column_name>ProdMkt_WPC.ProdCode</column_name>
                <column_name>ProdMkt_WPC.WPC_ID</column_name>
                <column_name>ProdMkt_WPC.Inactive</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_product_contributor_link_query(ids)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>ProdMkt_Contrib_Link.ProdMkt_ID</column_name>
                  <comparator>in</comparator>
                  <value>#{ids.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                <view_owner_table_name>ProdMkt_Contrib_Link</view_owner_table_name>
                <view_name>ProdMkt_Contrib_LinkAllRead</view_name>
                <column_name>ProdMkt_Contrib_Link.ProdMkt_Contrib_ID</column_name>
                <column_name>ProdMkt_Contrib_Link.ProdMkt_ID</column_name>
                <column_name>ProdMkt_Contrib_Link.Inactive</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_acumen_query_auth()
      <<~XML
          <authentication>
            <site_code>#{@auth['site_code']}</site_code>
            <password>#{@auth['password']}</password>
          </authentication>
          <message_version>1.00</message_version>
      XML
  end
end
