require 'huginn_agent'

HuginnAgent.load 'huginn_acumen_product_agent/concerns/acumen_product_query_concern'
HuginnAgent.load 'huginn_acumen_product_agent/acumen_client'

HuginnAgent.register 'huginn_acumen_product_agent/acumen_product_agent'
