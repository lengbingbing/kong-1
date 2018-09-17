local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.abtest.access"
local DynamicUpstreamHandler = BasePlugin:extend()

DynamicUpstreamHandler.PRIORITY = 10

function DynamicUpstreamHandler:new()
	DynamicUpstreamHandler.super.new(self, "abtest")
end



function DynamicUpstreamHandler:rewrite(conf)
  DynamicUpstreamHandler.super.rewrite(self)
  access.execute(conf)
end

return DynamicUpstreamHandler
