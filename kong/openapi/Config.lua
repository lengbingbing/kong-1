
local resty_consul = require('kong.openapi.Consul')
local cjson = require "cjson"
local json_decode = cjson.decode
local json_encode = cjson.encode
config = {};
config.cache = {}
config.consul= {}
config.debug={}
config.cache.get = 1 --静态化仅开启get请求
-- config.cache.path =  "/usr/local/opt/kong/runtime/cache"
-- config.consul.host = '10.168.100.164'
-- config.consul.port = 8500
-- config.debug.auto_reg = true
-- config.debug.cache = true
-- config.debug.error_handler =true

config.cache.path =  "/data/bigdata/kong/runtime/cache"
config.consul.host = '10.23.27.87'
config.consul.port = 80
config.debug.auto_reg = true
config.debug.cache = true
config.debug.error_handler =true


-- str是待分割的字符串 
local function split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

function config:new()
	local o = {};
	o = setmetatable( o, {__index = self} );
	return o;
end

---
-- @function:Consul 读取配置信息存入缓存
--
function config:setConfig()

		
		local consul = resty_consul:new({
		        host            = config.consul.host ,
		        port            = config.consul.port,
		        connect_timeout = (60*1000), -- 60s
		        read_timeout    = (60*1000), -- 60s
		        default_args    = {
		            -- token = "my-default-token"
		        },
		        ssl             = false,
		        ssl_verify      = true,
		        sni_host        = nil,
		    })
		local res, err = consul:list_keys('uc/openapi/config') 
        if not res then
            ngx.log(ngx.ERR, err)

        end
		local keys = {}
		if res.status == 200 then
		    keys = res.body
		end
		-- ngx.log(ngx.CRIT, 'key') 
		-- ngx.log(ngx.CRIT, res.status) 
		for _, key in ipairs(keys) do
		    local res, err = consul:get_key(key)
		    if not res then
		    
		        ngx.log(ngx.ERR, err)
		        return
		    end
		     -- ngx.log(ngx.CRIT, key) 
		     -- ngx.log(ngx.CRIT, res.body[1].Value) 
			 ngx.shared["static_config_cache"]:set(key,res.body[1].Value)	

			-- ngx.print(res.body[1].Value) -- Key value after base64 decoding
		end
        --open_api_domain_cache

		
end

---
-- @function: 获取限流配置信息
--
function config:getDomainTrafficConfig()
	local headers = ngx.req.get_headers() ;
    local host = split(headers["Host"],":")[1];
    local rootPath = 'uc/openapi/config/domain/';
    local path = rootPath..host;
    local cache_data = ngx.shared["static_config_cache"]:get(path);
    if cache_data ~= nil then
		local request_body = json_decode(cache_data)
		return request_body
	else
		return nil
    end

	
end

---
-- @function: 加载限流数据配置文件
--
function config:getUpstaremTrafficConfig()
	local headers = ngx.req.get_headers() ;
    local host = split(headers["Host"],":")[1];
	local uri = ngx.var.uri;
	local upstream_url = host..uri
    local replace_str =  string.gsub(upstream_url, "/", "-")
    local rootPath = 'uc/openapi/config/upstreamurl/';
    local consul_key = rootPath..replace_str;
    consul_key = string.lower(consul_key)
    -- ngx.log(ngx.CRIT, 'getUpstaremTrafficConfig--------consul_key'..consul_key) 
    local cache_data = ngx.shared["static_config_cache"]:get(consul_key);
    if cache_data ~= nil then
		local request_body = json_decode(cache_data)
		return request_body
	else
		return nil
    end

	
end



---
-- @function: 加载Abtest 配置文件
--
function config:getABTestConfig(key)

    local rootPath = 'uc/openapi/config/abtest/policy/';
    local consul_key = rootPath..key;
    local cache_data = ngx.shared["static_config_cache"]:get(consul_key);
    if cache_data ~= nil then
		local request_body = json_decode(cache_data)
		return request_body
	else
		return nil
    end

	
end

---
-- @function: 定时从 Consul 读取配置信息存入缓存
--
function config:loadConfig()

	  local delay = 5
	  local handler
	  -- do some routine job in Lua just like a cron job
	  handler = function (premature)
	      if premature then
	          return
	      end
	      local ok, err = ngx.timer.at(delay, handler)
	      if not ok then
	          ngx.log(ngx.CRIT, "failed to create the timer: ") 
	          return
	      else
	      	  config:setConfig()
		  end

	  end
	  if 0 == ngx.worker.id() then
	      local ok, err = ngx.timer.at(delay, handler)
	      if not ok then
	           ngx.log(ngx.CRIT, "failed to create the timer: ") 
	          return

	      end
	  end


end

return config;
