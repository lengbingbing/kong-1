local prometheus = require "kong.plugins.openapi-prometheus.exporter"


return {
  ["/metrics"] = {
    GET = function(self, dao_factory)
      prometheus.collect()
    end,
  },
}
