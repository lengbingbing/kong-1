
local resty_consul = require('kong.openapi.Consul')
local http = require('resty.http')
local tostring = tostring
local sub      = string.sub
local lower    = string.lower
local fmt      = string.format
local ngx      = ngx
local ERR      = ngx.ERR
local DEBUG    = ngx.DEBUG
local log      = ngx.log
local ngx_now  = ngx.now
local unpack   = unpack
local http = require "resty.http"
local cjson = require('cjson')
local json_decode = cjson.decode
local json_encode = cjson.encode
local tbl_concat = table.concat
local tbl_insert = table.insert
local tbl_insert = table.insert
local open_api_cache = require "kong.openapi.Cache"
local config = require("kong.openapi.Config");
local utils = require "kong.openapi.Utils"

ErrorHandlers = {}


function decodeURI(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end
---
-- @function: 根据参数名生成缓存文件名
-- @return: 文件名
-- function getCacheName(host,request_uri)
--     local filename= ngx.md5(host..request_uri)
--     return filename
-- end

function ErrorHandlers.writeCache()
    
            local name = nil
            local key = nil
            local uri = nil
            local request_args_tab = ngx.req.get_uri_args()
            for k, v in pairs(request_args_tab)   do
                   if(k=='name') then
                        name = v
                   end
                   if(k=='key') then
                        key = v
                   end
                   if(k=='uri') then
                        uri = v
                   end
            end
            local cache = open_api_cache:new();
            local  res =  cache:read(uri,name)
            if(res==false) then
                    --没有缓存默认走托底数据
                    local cache_data = ngx.shared["static_config_cache"]:get(key);
                    if cache_data ~= nil then
                            local request_body = json_decode(cache_data)
                            ngx.say(request_body.bottomJson)
                           
                    end
            else
                --读取到缓存数据
                for key, value in pairs(res) do  
                ngx.say(value)
                end 
               
            end
            return ngx.exit(200)

end

---
-- @function: 非500错误处理
-- @return: 
function ErrorHandlers.fallback_dispose()

     local request_args_tab = ngx.req.get_uri_args()
     local optype = request_args_tab.optype
     local name = request_args_tab.name
     local key = request_args_tab.key
     local uri = request_args_tab.uri
     local status = tonumber(request_args_tab.status)
     ngx.header["openapi_cache"] = request_args_tab.cache
     ngx.header["bottom_data"] = request_args_tab.bottom
     ngx.header["original_status"] = request_args_tab.status
     ngx.header["upstreamurl"] = request_args_tab.upstreamurl
     ngx.header["test"] = request_args_tab.upstreamurl
    if optype=='1' then
                ngx.header["optype"] = request_args_tab.optype
                utils.writeErrorHandlerLog( " request_args_tab.upstreamurl="..decodeURI(request_args_tab.upstreamurl)) 
                return ngx.exit(status)
     end
     --缓存
     if optype =='2' then
            ngx.header["optype"] = request_args_tab.optype
            local cache = open_api_cache:new();
            local res =  cache:read(uri,name)
            if(res==false) then
                 
                 return ngx.exit(status)
            else
                --读取到缓存数据
                for key, value in pairs(res) do  
                ngx.say(value)
                end 
                return ngx.exit(200)
            end
            
     end
     --托底
     if optype =='3' then
            ngx.header["optype"] = request_args_tab.optype
            local cache_data = ngx.shared["static_config_cache"]:get(key);
            if cache_data ~= nil then
                    local request_body = json_decode(cache_data)
                    ngx.say(request_body.bottomJson)
                    ngx.ctx.bottom = 1
            end

     end
     --分流
     if optype =='5' then
            ngx.header["separate"] = "1"
            local cache = open_api_cache:new();
            local res =  cache:read(uri,name)
            if(res==false) then
                 
                 return ngx.exit(status)
            else
                --读取到缓存数据
                for key, value in pairs(res) do  
                ngx.say(value)
                end 
                return ngx.exit(200)
            end
            
     end
end
---
-- @function: 读取配置，准备跳转参数
-- @return: 
function ErrorHandlers.buildJumpParms()
        local headers = ngx.req.get_headers()  
        local request_method = ngx.var.request_method
        local jump_url = nil
        local status = ngx.status

       

                utils.writeErrorHandlerLog( "request_method------------ "..request_method)
                if request_method=='GET' then


                        local request_uri = ngx.var.request_uri; 
                        local uri = nil
                        local args=nil
                        local path_index = string.find(request_uri,'?')
                        if(path_index~=nil) then
                              uri =  string.sub(request_uri,1,path_index-1)
                        else
                              uri = request_uri
                        end
                        local host = utils.split(headers["Host"],":")[1];
                        local upstream_url = host..uri
                        local child_key =  string.gsub(upstream_url, "/", "-")
                        local key = 'uc/openapi/config/upstreamurl/'..child_key
                        utils.writeErrorHandlerLog("key------------ "..key)
                        local cache_data = ngx.shared["static_config_cache"]:get(key);
                        if cache_data ~= nil then

                                local request_body = json_decode(cache_data)
                                utils.writeErrorHandlerLog("有数据 request_body.trafficFail="..request_body.trafficFail)
                                ngx.var.fault = "true"                
                                ngx.var.fault_strategy = request_body.trafficFail
                                ngx.header["fault"]= ngx.var.fault
                                ngx.header["fault_strategy"]= ngx.var.fault_strategy
                                Kong = require 'kong'
                                Kong.customLog()
                                --返回源码
                                if(request_body.trafficFail==1 or request_body.trafficFail=="1") then
                                    -- jump_url = '/fallback_dispose?optype=1&upstreamurl='..upstream_url..'&status='..status
                                    -- utils.writeErrorHandlerLog( "jump_url------------ "..jump_url)

                                    return false,nil
                                end
                                -- 缓存数据
                                if(request_body.trafficFail==2 or request_body.trafficFail=="2") then
                                   
                                    local cachename = utils.getCacheName(host,request_uri)
                                    local cache = open_api_cache:new();
                                    utils.writeErrorHandlerLog( "uri------------ "..uri)
                                    utils.writeErrorHandlerLog( "cachename------------ "..cachename)

                                    local data = ngx.shared["static_cache"]:get(cachename)
                                    -- 判断缓存是否过期
                                    if data == nill then 
                                         utils.writeErrorHandlerLog( "cachename------------过期 ")    
                                         return false,nil
                                    end
                                    local res =  cache:read(uri,cachename)
                                    if(res==false) then
                                        return false,nil
                                    else
                                        -- jump_url = '/fallback_dispose?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
                                        jump_url = '/openapi/error?name='..cachename..'&optype=2&uri='..uri
                                        return true,jump_url
                                    end

                                end
                                -- 托底
                                if(request_body.trafficFail==3 or request_body.trafficFail=="3") then
                                    -- ngx.say(request_body.bottomJson)
                                    local cachename = utils.getCacheName(host,request_uri)
                                    -- jump_url = '/fallback_dispose?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url

                                    jump_url = '/openapi/error?bottomJson='..request_body.bottomJson..'&optype=3'
                                    return true,jump_url
                                end
                      
                                if(request_body.trafficFail==4 or request_body.trafficFail=="4") then
                                    
                                    local cachename = utils.getCacheName(host,request_uri)
                                    local cache = open_api_cache:new();
                                    local data = ngx.shared["static_cache"]:get(cachename)
                                    local res =  cache:read(uri,cachename)
                                    if(res==false or data==nill) then
                                           
                                            -- jump_url = '/fallback_dispose?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url
                                            jump_url = '/openapi/error?bottomJson='..request_body.bottomJson..'&optype=3'
                                            return true,jump_url
                                    else


                                            -- jump_url = '/fallback_dispose?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
                                            jump_url = '/openapi/error?name='..cachename..'&optype=2&uri='..uri
                                            return true,jump_url
                                    end
                         

                                end
                        end
                        
                      

                end
             
        return false,jump_url
end


 
return ErrorHandlers