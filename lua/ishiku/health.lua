local health = vim.health or require("health")

local compat = require("ishiku.compat")
local registry = require("ishiku.registry")
local settings = require("ishiku.settings")
local state = require("ishiku.state")
local util = require("ishiku.util")

local M = {}

local function ok_or_warn(executable, advice)
  if vim.fn.executable(executable) == 1 then
    health.ok(("%s found"):format(executable))
  else
    health.warn(("%s not found"):format(executable), { advice })
  end
end

function M.check()
  health.start("ishiku.nvim")

  if compat.has(11) then
    health.ok(("Neovim version: %d.%d"):format(vim.version().major, vim.version().minor))
  else
    health.error("Neovim 0.11+ is required.", {
      "Current runtime is older than 0.11.",
    })
    return
  end

  health.ok(("registry parsers: %d"):format(#registry.names()))
  health.ok(("install_root_dir: %s"):format(settings.current.install_root_dir))

  if util.exists(state.install_root_dir()) then
    health.ok("install root exists")
  else
    health.info("install root has not been created yet")
  end

  ok_or_warn("git", "Required for fetching parser sources.")

  local compiler = util.select_executable(settings.current.compilers)
  if compiler then
    health.ok(("compiler found: %s"):format(compiler))
  else
    health.error("No supported C compiler found.", {
      "Install one of: cc, gcc, clang, cl, zig.",
    })
  end

  if vim.fn.executable("tree-sitter") == 1 then
    health.ok("tree-sitter CLI found")
  else
    health.info("tree-sitter CLI missing; parsers that require generate will fail to install")
  end

  if vim.fn.executable("node") == 1 then
    health.ok("node found")
  else
    health.info("node missing; parsers that require generate will fail to install")
  end

  if vim.fn.executable("npm") == 1 then
    health.ok("npm found")
  else
    health.info("npm missing; parsers with npm generation dependencies will fail to install")
  end
end

return M
