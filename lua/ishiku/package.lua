local receipt = require("ishiku.receipt")
local state = require("ishiku.state")

local Package = {}
Package.__index = Package

function Package:new(name, spec, registry, installer)
  return setmetatable({
    name = name,
    spec = spec,
    registry = registry,
    installer = installer,
  }, self)
end

function Package:get_locked_revision()
  return self.registry.locked_revision(self.name)
end

function Package:get_source()
  return self.spec.source
end

function Package:get_build()
  return self.spec.build
end

function Package:get_receipt()
  return receipt.read(self.name)
end

function Package:is_installed()
  return state.is_installed(self.name)
end

function Package:is_installing()
  return self.installer.is_pending(self.name)
end

function Package:is_outdated()
  return self.registry.outdated(self.name)
end

function Package:install(opts, callback)
  return self.installer.install(self.name, opts or {}, callback)
end

function Package:update(callback)
  return self.installer.update({ self.name }, callback)
end

function Package:uninstall()
  return self.installer.uninstall(self.name)
end

return Package
