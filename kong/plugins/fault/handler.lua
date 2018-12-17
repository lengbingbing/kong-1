local BasePlugin = require "kong.plugins.base_plugin"

local cjson = require "cjson"
local responses = require "kong.tools.responses"
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local body_filter = require "kong.plugins.response-transformer.body_transformer"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_body_transform_set = header_filter.is_body_transform_set
local is_json_body = header_filter.is_json_body
local http = require "resty.http"
local open_api_cache = require "kong.openapi.Cache"
local traffic_cache = require "kong.openapi.TrafficCache"
local utils = require "kong.openapi.Utils"
-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.


local FaultHandler = BasePlugin:extend()


FaultHandler.PRIORITY = 9998
FaultHandler.VERSION = "0.1.0"



function FaultHandler:new()
  FaultHandler.super.new(self, "my-custom-plugin")
end

function FaultHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  FaultHandler.super.init_worker(self)

  -- Implement any custom logic here
end

function FaultHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  FaultHandler.super.certificate(self)

  -- Implement any custom logic here
end

function FaultHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  FaultHandler.super.rewrite(self)
  

  -- Implement any custom logic here
end




function FaultHandler:access(config)
                -- Eventually, execute the parent implementation
                -- (will log that your plugin is entering this context)

      ngx.var.fault_enabled="true"


end

function FaultHandler:header_filter(config)

   FaultHandler.super.header_filter(self)

end

function FaultHandler:body_filter(conf)
    FaultHandler.super.body_filter(self)

   
end

function FaultHandler:log(config)
      FaultHandler.super.log(self)

end


return FaultHandler