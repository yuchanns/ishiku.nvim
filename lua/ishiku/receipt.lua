local state = require("ishiku.state")
local util = require("ishiku.util")

local M = {}

function M.read(lang)
  return util.read_json(state.receipt_path(lang))
end

function M.write(lang, receipt)
  util.write_json(state.receipt_path(lang), receipt)
end

return M
