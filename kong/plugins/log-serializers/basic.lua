local tablex = require "pl.tablex"

local _M = {}

local EMPTY = tablex.readonly({})

function _M.serialize(ngx)
  local authenticated_entity
  if ngx.ctx.authenticated_credential ~= nil then
    authenticated_entity = {
      id = ngx.ctx.authenticated_credential.id,
      consumer_id = ngx.ctx.authenticated_credential.consumer_id
    }
  end

  local request_uri = ngx.var.request_uri or ""
  local no_arg_uri = nil
  local path_index = string.find(request_uri,'?')
  if(path_index~=nil) then
     no_arg_uri =  string.sub(request_uri,1,path_index-1)
  else
     no_arg_uri = request_uri
  end
  
  return {
    request = {
      uri = request_uri,
      url = ngx.var.scheme .. "://" .. ngx.var.host .. no_arg_uri,
      querystring = ngx.req.get_uri_args(), -- parameters, as a table
      method = ngx.req.get_method(), -- http method
      headers = ngx.req.get_headers(),
      size = ngx.var.request_length
    },
    upstream_uri = ngx.var.upstream_uri,
    response = {
      status = ngx.status,
      headers = ngx.resp.get_headers(),
      size = ngx.var.bytes_sent
    },
    tries = (ngx.ctx.balancer_data or EMPTY).tries,
    latencies = {
      kong = (ngx.ctx.KONG_ACCESS_TIME or 0) +
             (ngx.ctx.KONG_RECEIVE_TIME or 0) +
             (ngx.ctx.KONG_REWRITE_TIME or 0) +
             (ngx.ctx.KONG_BALANCER_TIME or 0),
      proxy = ngx.ctx.KONG_WAITING_TIME or -1,
      request = ngx.var.request_time * 1000
    },
    openapi={

      cocurrent= ngx.var.cocurrent,
      cocurrent_strategy= ngx.var.cocurrent_strategy,
      cocurrent_concurrency= ngx.var.cocurrent_concurrency,
      cocurrent_remark= ngx.var.cocurrent_remark,
      cache= ngx.var.cache,
      cache_percentage= ngx.var.cache_percentage,
      fault= ngx.var.fault,
      fault_strategy= ngx.var.fault_strategy,



    },
    authenticated_entity = authenticated_entity,
    route = ngx.ctx.route,
    service = ngx.ctx.service,
    api = ngx.ctx.api,
    consumer = ngx.ctx.authenticated_consumer,
    client_ip = ngx.var.remote_addr,
    started_at = ngx.req.start_time() * 1000
  }
end

return _M
