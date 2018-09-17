local config = require("kong.openapi.Config");
OpenApiUtils = {}



-- 字符串拆分
function OpenApiUtils.split(str,reps)
    local resultStrList = {}
    
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

-- 过期网关hosts
function OpenApiUtils.getHostName()
    local headers = ngx.req.get_headers()
    local host = OpenApiUtils.split(headers["Host"],":")[1]
    return host
end

-- 生成缓存名称
function OpenApiUtils.getCacheName(host,request_uri)
    local filename= ngx.md5(host..request_uri)
    return filename
end

-- 自动注册日志，是否写入调试日志
function OpenApiUtils.writeAutoRegLog(msg)
   
   if config.debug.auto_reg then
   	  ngx.log(ngx.CRIT, msg)	
   end
   
end

-- 缓存限流，是否写入调试日志
function OpenApiUtils.writeCacheLog(msg)
   
   if config.debug.cache then
   	  ngx.log(ngx.CRIT, msg)	
   end
   
end
function OpenApiUtils.writeErrorHandlerLog(msg)
   
   if config.debug.error_handler then
   	  ngx.log(ngx.CRIT, msg)	
   end
   
end


return OpenApiUtils