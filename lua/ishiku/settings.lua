local util = require("ishiku.util")

local M = {}

local DEFAULT_SETTINGS = {
  install_root_dir = util.joinpath(vim.fn.stdpath("data"), "ishiku"),
  ensure_installed = {},
  auto_install = false,
  sync_install = false,
  prefer_git = vim.fn.has("win32") == 1,
  max_concurrent_installers = 4,
  registries = {
    "github:yuchanns/ishiku-registry",
  },
  parser_aliases = {},
  compilers = {
    vim.fn.getenv("CC"),
    "cc",
    "gcc",
    "clang",
    "cl",
    "zig",
  },
  ui = {
    border = nil,
    width = 0.8,
    height = 0.85,
    icons = {
      installed = "✓",
      pending = "➜",
      uninstalled = "·",
      outdated = "!",
      failed = "✗",
    },
  },
}

M.current = vim.deepcopy(DEFAULT_SETTINGS)

function M.set(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_SETTINGS), opts or {})
end

return M
