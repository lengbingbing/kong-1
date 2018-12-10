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


local TrafficHandler = BasePlugin:extend()


TrafficHandler.PRIORITY = 5003
TrafficHandler.VERSION = "0.1.0"



function TrafficHandler:new()
  TrafficHandler.super.new(self, "my-custom-plugin")
end

function TrafficHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.init_worker(self)

  -- Implement any custom logic here
end

function TrafficHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.certificate(self)

  -- Implement any custom logic here
end

function TrafficHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.rewrite(self)
  

  -- Implement any custom logic here
end





function TrafficHandler:access(config)
                -- Eventually, execute the parent implementation
                -- (will log that your plugin is entering this context)

                TrafficHandler.super.access(self)
                local request_method = ngx.var.request_method

                -- 添加判断、只处理GET 请求
                if request_method=='GET' then
                       --是否按百分比走缓存数据
                       if(config.percentage>0) then    
                            local count =  math.random(1,100)
                            utils.writeCacheLog( "count= " ..count) 
                            if count<= config.percentage then
                                    utils.writeCacheLog( "output cache data ") 
                                    traffic_cache:outputPercentageCache(config.domain)
               
                            end

                        end
                              
                   

                end

end

function TrafficHandler:header_filter(config)

   TrafficHandler.super.header_filter(self)

end

function TrafficHandler:body_filter(conf)
    TrafficHandler.super.body_filter(self)

   
end

function TrafficHandler:log(config)
    TrafficHandler.super.log(self)

end


return TrafficHandler