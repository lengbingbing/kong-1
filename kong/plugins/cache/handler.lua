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

local CacheHandler = BasePlugin:extend()


CacheHandler.PRIORITY = 5000
CacheHandler.VERSION = "0.1.0"



function CacheHandler:new()
  CacheHandler.super.new(self, "my-custom-plugin")
end

function CacheHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CacheHandler.super.init_worker(self)

  -- Implement any custom logic here
end

function CacheHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CacheHandler.super.certificate(self)

  -- Implement any custom logic here
end

function CacheHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CacheHandler.super.rewrite(self)
  

  -- Implement any custom logic here
end


-- @strategy: 并发处理策略
-- @bottomJson: 托底数据
-- @status: z状态
function buildCacheJumpParms(percentage)
                   
                  
                    local request_uri = ngx.var.request_uri; 
                    local host = utils.getHostName()
                    local uri = ngx.var.uri;
                    local jump_url = nil
                    local upstream_url = host..uri
                    local child_key =  string.gsub(upstream_url, "/", "-")
                    local cachename = utils.getCacheName(host,request_uri)
                    local data = ngx.shared["static_cache"]:get(cachename)
                    -- 判断缓存是否过期
                    if data == nill then 
                        ngx.log(ngx.CRIT, "cachename------------过期 ")    
                        return false,nil
                    end
                    local cache = open_api_cache:new();
                    local res =  cache:read(uri,cachename)
                    if(res==false) then
                        ngx.log(ngx.CRIT, "没有缓存文件------------过期 cachename="..cachename)    
                       return false,nil
                    else
                       
                       jump_url = '/openapi/cocurrent?name='..cachename..'&optype=2&uri='..uri
                       utils.writeCacheLog( "jump_url="..jump_url)  
                       return true,jump_url
                   end
end


-- @cacheResponse: 缓存数据处理
-- @percentage: 分流概率
function cacheResponse(percentage)
       ngx.log(ngx.CRIT, "cacheResponse--------------") 
      local res, jump_url = buildCacheJumpParms(percentage)
      if res then
            ngx.log(ngx.CRIT, "cacheResponse--------------true") 
            ngx.var.cache="true"
            ngx.var.cache_percentage= percentage
            ngx.header["cache"]=ngx.var.cache
            ngx.header["cache_percentage"]=ngx.var.cache_percentage
            utils.writeCacheLog( "jump_url " .. jump_url) 
            Kong = require 'kong'
            Kong.customLog()
            return ngx.exec(jump_url) 
      end




end


function CacheHandler:access(conf)
                local request_method = ngx.var.request_method
                 utils.writeCacheLog( "CacheHandler")  
                -- 添加判断、只处理GET 请求
                if request_method=='GET' then
                    local cache = open_api_cache:new();
                    save_cache_res = cache:setCache(conf.domain,conf.minute)
                    --是否按百分比走缓存数据
                    if(conf.percentage>0) then    
                            local count =  math.random(1,100)
                            utils.writeCacheLog( "count= " ..count) 
                            if count<= conf.percentage then
                                    utils.writeCacheLog( "output cache data ") 
                                    cacheResponse(conf.percentage)
               
                            end
                    else
                          utils.writeCacheLog( "cacheResponse")  
                          cacheResponse(0)

                    end


                end
               
   CacheHandler.super.access(self)

end

function CacheHandler:header_filter(config)

   CacheHandler.super.header_filter(self)

end

function CacheHandler:body_filter(config)
 CacheHandler.super.body_filter(self)

   
end

function CacheHandler:log(config)
   

                CacheHandler.super.log(self)

end


return CacheHandler