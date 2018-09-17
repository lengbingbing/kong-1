local IpParser = require "kong.plugins.abtest.ipParser"

local log
local ERR      = ngx.ERR
local ngx_get_headers = ngx.req.get_headers
local open_api_config = require "kong.openapi.Config"
local config =  open_api_config:new()

do
  local ngx_log = ngx.log
  log = function(lvl, ...)
    ngx_log(lvl, "[router] ", ...)
  end
end

local _M = {}

string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

function _M.execute(conf)
  local headers = ngx_get_headers()
  local scheme = ngx.var.scheme
  local request_uri = ngx.var.request_uri

  local requestUrl = headers["Host"]..request_uri 
  local key = string.split(requestUrl,"?")[1]
  
  local json = config:getABTestConfig(string.gsub(key,"/","-"))
  local i = 1
  local j = 1
  if json~=nil then
    local status = json.status
    if status=='0' then
      local plist = json.iplist
      local klist = json.kvlist
      while i<=#plist do
        local clientIp = IpParser:get()
        local minIp = plist[i].minip 
        local maxIp = plist[i].maxip
        if(clientIp>=IpParser:cip2long(minIp) and clientIp<=IpParser:cip2long(maxIp)) then
          ngx.var.abtesthost = plist[i].host
          ngx.var.abtesturis = plist[i].uris
        end
        i = i+1  
      end
      while j<=#klist do
        local key = klist[j].key 
        local value = klist[j].value
        if(headers[key]) then
          if(headers[key]==value) then
              ngx.var.abtesthost = klist[j].host
              ngx.var.abtesturis = klist[j].uris
          end        
        end
        j = j+1  
      end
    end
  end   
    
   

end

return _M
