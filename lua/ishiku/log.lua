local state = require("ishiku.state")
local util = require("ishiku.util")

local M = {}

local function timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

function M.path()
  state.ensure()
  return state.log_path()
end

function M.append(message)
  local path = M.path()
  vim.fn.writefile({ ("[%s] %s"):format(timestamp(), message) }, path, "a")
end

function M.command(cmd, opts)
  local cwd = opts and opts.cwd or vim.loop.cwd()
  M.append(("cwd=%s cmd=%s"):format(cwd, table.concat(cmd, " ")))
end

function M.result(result)
  M.append(("exit=%s"):format(result.code))
  if result.stdout and result.stdout ~= "" then
    M.append("stdout:")
    for _, line in ipairs(vim.split(result.stdout, "\n", { plain = true })) do
      if line ~= "" then
        M.append(line)
      end
    end
  end
  if result.stderr and result.stderr ~= "" then
    M.append("stderr:")
    for _, line in ipairs(vim.split(result.stderr, "\n", { plain = true })) do
      if line ~= "" then
        M.append(line)
      end
    end
  end
end

function M.open()
  util.open(M.path())
end

return M
