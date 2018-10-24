
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

TrafficCache = {}


--限流输出缓存
function TrafficCache.writeCache()
    
     local request_args_tab = ngx.req.get_uri_args()
     local optype = request_args_tab.optype
     local name = request_args_tab.name
     local key = request_args_tab.key
     local uri = request_args_tab.uri
     local status = tonumber(request_args_tab.status)
     ngx.header["original_status"] = request_args_tab.status
     
     ngx.log(ngx.CRIT, 'optype='..optype)    

    if optype=='1' then
                utils.writeCacheLog( " request_args_tab.upstreamurl="..decodeURI(request_args_tab.upstreamurl)) 

                return ngx.exit(status)
     end
     --缓存
     if optype =='2' or optype =='5'  then
            local cache = open_api_cache:new();
            local res =  cache:read(uri,name)
            ngx.log(ngx.CRIT, 'uri='..uri)    


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
           
            local cache_data = ngx.shared["static_config_cache"]:get(key);
            if cache_data ~= nil then
                    local request_body = json_decode(cache_data)
                    ngx.say(request_body.bottomJson)
                    ngx.ctx.bottom = 1
            end

     end

end

-- 根据策略、拼接跳转所需要参数
function TrafficCache:buildJumpParms(strategy,domain,body,status)

            
            local request_uri = ngx.var.request_uri; 
            local host = utils.getHostName()
            local uri = ngx.var.uri;
            local jump_url = nil
            local upstream_url = host..uri
            local child_key =  string.gsub(upstream_url, "/", "-")
            local key = 'uc/openapi/config/upstreamurl/'..child_key
            if(strategy==1) then
                jump_url = '/outputdata?optype=1'..'&status='..status..'&upstreamurl='..upstream_url
                return true,jump_url
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
                       jump_url = '/outputdata?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
                       return true,jump_url
                   end

           end
           -- 托底
           if(strategy==3) then
                
                jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url
                return true,jump_url
            end
              
            if(strategy==4) then
                local cachename = utils.getCacheName(host,request_uri)    
                local data = ngx.shared["static_cache"]:get(cachename)
                -- 判断缓存是否过期
                if data == nill then 
                         jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url
                         return true,jump_url
                end         
                local cache = open_api_cache:new();
                local res =  cache:read(uri,cachename)
                if(res==false) then
                         
                         jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url
                         return true,jump_url
                else
                         jump_url = '/outputdata?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
                         return true,jump_url
                end
                     

             end
            -- 分流
            if(strategy==5) then

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
                       jump_url = '/outputdata?name='..cachename..'&optype=5&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false&upstreamurl='..upstream_url
                       return true,jump_url
                   end

           end


end
-- 跳转、输出缓存
function TrafficCache:outputCacheData(strategy,domain,body,status)
        
      local res, jump_url = TrafficCache:buildJumpParms(strategy,domain,body,status)

      if res then
            utils.writeCacheLog( "jump_url " .. jump_url) 
            return ngx.exec(jump_url) 
            
      else
            return ngx.exit(status)
      end
end
--返回按百分比限流的数据
function TrafficCache:outputPercentageCache(domain)

      local res, jump_url = TrafficCache:buildJumpParms(5,domain,'',200)
     
      if res then
            utils.writeCacheLog("百分比输出，跳转链接==" .. jump_url) 
            return ngx.exec(jump_url) 
      end


end
 
return TrafficCache