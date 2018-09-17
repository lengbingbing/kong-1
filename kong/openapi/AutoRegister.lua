
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
local utils = require "kong.openapi.Utils"
local config = require("kong.openapi.Config");
AutoRegister = {}

---
-- @function: 检测url是否存在，判断是否返回404 ,如果返回404不注册到 kong中 
-- @param: url
-- @return: true or false
local function check_url_exists(request_uri,num_retries)
    utils.writeAutoRegLog(" start fetch " .. request_uri)    
    local http = require "resty.http"
    local httpc = http.new()
    httpc:set_timeout(1000)
    local res, err = nil
    while(num_retries > 0 and res == nil)
    do
        utils.writeAutoRegLog( "try request_uri" .. request_uri)
        res, err = httpc:request_uri(request_uri, {
            method = "GET",   
            headers = {
                ["scheme"] = "http",
                ["accept"] = "*/*",
                -- ["accept-encoding"] = "gzip",
                ["cache-control"] = "no-cache",
                ["pragma"] = "no-cache",
            } ,            
        })
        if res == nil then 
           return nil
        end
        utils.writeAutoRegLog("res.status="..res.status)
        if res.status == 404 or  res.status ==302 then 
              res = nil
              break
        end
        num_retries = num_retries - 1 
        utils.writeAutoRegLog("num retries: " .. num_retries)
  
    end

    http:close()
    if res == nil then 
        return nil
    end
    return res.body


end
--获取路径
local function stripfilename(filename)
   ngx.log(ngx.CRIT, 'filename='..filename)  
  return string.match(filename, "(.+)/[^/]*%.%w+$") --*nix system
  --return string.match(filename, “(.+)\\[^\\]*%.%w+$”) — windows
end

function check_sub_path(arr,paths)
  local flg = false
  local sub_path =''
  for key, value in pairs(arr) do  
    sub_path= sub_path..'/'..value
    
    if(sub_path==paths) then 
      flg=true
      break
    end


  end 
  return flg
  
end

---
-- @function: 检查path 是否符合规则，符合规则注册到kong中 
-- @param: url
-- @return: true or false
local function check_path_exists(paths)
    

   
    local uri = ngx.var.uri
    local path_table = utils.split(paths,',')
    local flg = false
    for key, value in pairs(path_table) do  

          if(#value>0) then
             
              value = string.gsub(value,",","")
             --都转换成小写进行路径比较             
              local res = string.match(string.lower(uri), '^'..string.lower(value))
              if res ~=nil then
                  flg = true
                  utils.writeAutoRegLog("check_path_exists------result=true" )
                  break
              else
                  ngx.log(ngx.CRIT, 'uri='..uri)  
                  local temp_url = stripfilename(uri)
                  local arr  = nil
                  if temp_url==nil then
                        arr = utils.split(uri,'/')
                  else
                        rr = utils.split(stripfilename(uri),'/')

                  end
                 
                  local sub_flg = check_sub_path(arr,value)
                  if sub_flg then
                        flg = true
                        utils.writeAutoRegLog("check_path_exists---two--------result=true" )
                        break
                  else

                        utils.writeAutoRegLog("check_path_exists------result=false" )
                        utils.writeAutoRegLog("ngx.var.uri="..string.lower(uri) )
                        utils.writeAutoRegLog("paths.value="..string.lower(value))
                        utils.writeAutoRegLog("res  request_filename="..ngx.var.request_filename )
                  end

                 
              end
          end


    end 

    
    return flg


end



-- @function: 同步数据到mysql
-- @param: uri 
-- @param: value   保存到consul 中的 注册KongApi 的 Json 数据
-- @return: return
local function prepareRegData(uri,value)
           
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
            local replace_str =  string.gsub(uri, "/", "-")
            local save_key = 'uc/openapi/autoreg/'..replace_str
            local res, err = consul:get_key(save_key)
            if not res then
                utils.writeAutoRegLog('prepareRegData get key error ='..err)
                return
        
            end         
            -- key not exists    
            if res.status ~= 200 then  
                res, err = consul:put_key(save_key,  value)
                if not res then
                    utils.writeAutoRegLog('prepareRegData put_key error ='..err)
                end
                utils.writeAutoRegLog('prepareRegData write save success, res.status ='..res.status )
            end
end

-- @function: 不符合规则的uri 保存到consul 中
-- @param: domain : 源域名
-- @param: value:不符合规则的uri
-- @return: return
local function inconformityRegData(domain,value)

           
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
         
            local key = 'uc/openapi/unautoreg/'..domain
         
            local res, err = consul:get_key(key)
            if not res then
                utils.writeAutoRegLog(err)
                return
        
            end
           

            if res.status == 404 then
                local res, err = consul:put_key(key,  value)
                if not res then
                    ngx.log(err)
                end
                
            else
               local data = res.body[1].Value
             
               local save_data = data..','..value
               utils.writeAutoRegLog('data='..save_data)
               res, err = consul:put_key(key,save_data)
               if not res then
                  utils.writeAutoRegLog('writeAutoRegLog ='..err )
                 
               end
               
            end


end






-- @function: 自动注册函数
-- @return: return
function AutoRegister.reg()
    --nginx变量  
  
        local headers = ngx.req.get_headers() ;
        local host = utils.split(headers["Host"],":")[1];
        local rootPath = 'uc/openapi/config/domain/';
        local path = rootPath..host;
        local uri = ngx.var.uri
        local cache_data = ngx.shared["static_config_cache"]:get(path);
        if cache_data ~= nil then
            
            local request_body = json_decode(cache_data)
            --匹配域名是否需要自动注册功能
         
            
            if  request_body.hosts == host then
                    local upstream_url = request_body.domain..ngx.var.uri
                    utils.writeAutoRegLog('string.match(request_body.hosts,host) ')  
                    match_t = {} 
                    match_t.upstream_url_t={}
                    match_t.upstream_url_t.host= string.gsub(request_body.domain, "http://", "")  
                    match_t.upstream_url_t.scheme=request_body.protocol
                    match_t.upstream_url_t.port=80
                    match_t.upstream_url_t.type="name"
                    
                   



                    match_t.api={}
                    match_t.api.created_at="1527211899491"
                    match_t.api.strip_uri="true"
                    match_t.api.id=""
                    match_t.api.name=""
                    match_t.api.hosts={host}
                    match_t.api.headers={}
                    match_t.api.headers.host={host}
                    match_t.api.http_if_terminated=false
                    match_t.api.https_only=false
                    match_t.api.retries=5
                    match_t.api.uris=uri
                    match_t.api.upstream_url=upstream_url
                    match_t.api.upstream_send_timeout=60000
                    match_t.api.upstream_read_timeout=60000
                    match_t.api.upstream_connect_timeout=60000
                    match_t.api.preserve_host= false


                    
                    match_t.matches={}
                    match_t.matches.host={host}
                    match_t.matches.uri=uri
                    

                    match_t.upstream_scheme=request_body.protocol
                    match_t.upstream_uri=ngx.var.uri


                    -- 
                    
                    --检查源站是否可以正常访问  
                    local flg = check_path_exists(request_body.paths)
                    if flg then
                        -- 判断源是否可用
                        if check_url_exists(request_body.domain..uri,3)~=nil then
                              local publish ={}        
                              publish["uris"]= ngx.var.uri
                              publish["requestUrl"]= host..ngx.var.uri
                              publish["hosts"]= host
                              publish["methods"]= "POST,GET"
                              publish["timeout"]= request_body.timeout
                              publish["creater"]= request_body.creater
                              publish["isDelete"]= 0
                              publish["remark"]= " "
                              publish["deptid"]= request_body.deptid
                              publish["isAuth"]= 0
                              utils.writeAutoRegLog(" start prepareRegData")
                              prepareRegData(ngx.var.uri,publish)
                        else
                              utils.writeAutoRegLog("验证源地址失败")
                        end
                    else
                        --保存不符合uri配置的，信息到consul
                        inconformityRegData(match_t.upstream_url_t.host,ngx.var.uri)
                       
                    end
   

            end

           return match_t    
        end
        return nil

end
 

 
return AutoRegister