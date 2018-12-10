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


local CocurrentHandler = BasePlugin:extend()


CocurrentHandler.PRIORITY = 5001
CocurrentHandler.VERSION = "0.1.0"


function CocurrentHandler:new()
  CocurrentHandler.super.new(self, "cocurrent")
end

function CocurrentHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CocurrentHandler.super.init_worker(self)

  -- Implement any custom logic here
end

function CocurrentHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CocurrentHandler.super.certificate(self)

  -- Implement any custom logic here
end

function CocurrentHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CocurrentHandler.super.rewrite(self)
  

  -- Implement any custom logic here
end

local function getIP()
    local ClientIP = ngx.req.get_headers()["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = ngx.req.get_headers()["X-Forwarded-For"]
        if ClientIP then
            local colonPos = string.find(ClientIP, ' ')
            if colonPos then
                ClientIP = string.sub(ClientIP, 1, colonPos - 1) 
            end
        end
    end
    if ClientIP == nil then
        ClientIP = ngx.var.remote_addr
    end
    if ClientIP then 
        ClientIP = ClientIP
    end
    return ClientIP
end


-- @strategy: 并发处理策略
-- @bottomJson: 托底数据
-- @status: z状态
function buildJumpParms(strategy,body,status)

            local request_uri = ngx.var.request_uri; 
            local host = utils.getHostName()
            local uri = ngx.var.uri;
            local jump_url = nil
            local upstream_url = host..uri
            local child_key =  string.gsub(upstream_url, "/", "-")
            local key = 'uc/openapi/config/upstreamurl/'..child_key
            if(strategy==1) then
                -- jump_url = '/outputdata?optype=1'..'&status='..status..'&upstreamurl='..upstream_url
                return false,nil
                            -- return false,nil
            end
            -- 缓存数据
            if(strategy==2) then

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
                       return true,jump_url
                   end

           end
           -- 托底
           if(strategy==3) then
                
                jump_url = '/openapi/cocurrent?bottomJson='..body..'&optype=3'
                return true,jump_url
            end
              
            if(strategy==4) then
                local cachename = utils.getCacheName(host,request_uri)    
                local data = ngx.shared["static_cache"]:get(cachename)
                -- 判断缓存是否过期
                if data == nill then 
                         jump_url = '/openapi/cocurrent?bottomJson='..body..'&optype=3'
                         return true,jump_url
                end         
                local cache = open_api_cache:new();
                local res =  cache:read(uri,cachename)
                if(res==false) then
                         
                         jump_url = '/openapi/cocurrent?bottomJson='..body..'&optype=3'
                         return true,jump_url
                else
                         jump_url = '/openapi/cocurrent?name='..cachename..'&optype=2&uri='..uri
                         return true,jump_url
                end
                     

             end
           --  -- 分流
           --  if(strategy==5) then

           --          local cachename = utils.getCacheName(host,request_uri)
           --          local data = ngx.shared["static_cache"]:get(cachename)
           --          -- 判断缓存是否过期
           --          if data == nill then 
           --              ngx.log(ngx.CRIT, "cachename------------过期 ")    
           --              return false,nil
           --          end
           --          local cache = open_api_cache:new();
           --          local res =  cache:read(uri,cachename)
           --          if(res==false) then
           --              ngx.log(ngx.CRIT, "没有缓存文件------------过期 cachename="..cachename)    
           --             return false,nil
           --          else
           --             jump_url = '/outputdata?name='..cachename..'&optype=5&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
           --             return true,jump_url
           --         end

           -- end





end


-- @concurrency: concurrency 并发数
-- @strategy: 并发处理策略
-- @bottomJson: 托底数据
-- @status: z状态
-- @remark: 备注
function cocurrentResponse(concurrency,strategy,bottomJson,status,remark)


      ngx.var.cocurrent="true"
      ngx.var.cocurrent_strategy= strategy
      ngx.var.cocurrent_concurrency= concurrency
      ngx.var.cocurrent_remark= remark
      ngx.header["cocurrent"]=ngx.var.cocurrent
      ngx.header["cocurrent_strategy"]=ngx.var.cocurrent_strategy
      ngx.header["cocurrent_concurrency"]=ngx.var.cocurrent_concurrency
     
      local res, jump_url =buildJumpParms(strategy,bottomJson,status)
      if res then
            utils.writeCacheLog( "jump_url " .. jump_url) 
            Kong = require 'kong'
            Kong.customLog()
            return ngx.exec(jump_url) 
            
      else
            return ngx.exit(status)
      end




end




function CocurrentHandler:access(conf)
                -- Eventually, execute the parent implementation
                -- (will log that your plugin is entering this context)
                ngx.log(ngx.CRIT, 'CocurrentHandler')
                CocurrentHandler.super.access(self)

                                  -- -- 并发限流
                                  -- upstream_config_data.trafficStrategy   value=1 返回缓存数据 value=2 返回托底数据  
                                  -- upstream_config_data.bottomJson        托底数据
                                  if(conf.concurrency>0 ) then
                                        local limit_req = require "resty.limit.req"
                                        local lim, err = limit_req.new("my_limit_req_store", conf.concurrency, 1)
                                        if not lim then --申请limit_req对象失败
                                           cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"申请limit_req对象失败" )
    
                                            
                                        end
                                        -- 使用ip地址作为限流的key
                                        local key = getIP()
                                        local delay, err = lim:incoming(key, true)
                                        if not delay then
                                        if err == "rejected" then
                                               
                                             --超时
                                             cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"超时" )
                                             ngx.log(ngx.ERR,"rejected")

                                        end
                                            
                                            cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"not rejected" )
                                            ngx.log(ngx.ERR,"not rejected")

                                        end
                                        if delay~=nil and delay > 0 then
                                              
                                              
                                              cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"delay" )
                                              ngx.log(ngx.ERR,"delay")
                                        end
                                   end
         

end

function CocurrentHandler:header_filter(config)

   CocurrentHandler.super.header_filter(self)

end

function CocurrentHandler:body_filter(conf)
    CocurrentHandler.super.body_filter(self)

   
end

function CocurrentHandler:log(config)
   



end


return CocurrentHandler