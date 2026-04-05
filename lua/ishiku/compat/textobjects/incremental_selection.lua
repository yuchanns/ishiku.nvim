local compat = require("ishiku.compat")

if compat.is_0_12_or_newer() then
  return require("ishiku.compat.textobjects.incremental_selection_012")
end

return require("ishiku.compat.textobjects.incremental_selection_011")
