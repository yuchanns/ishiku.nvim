local util = require("ishiku.util")

local M = {}

local DEFAULT_SETTINGS = {
  install_root_dir = util.joinpath(vim.fn.stdpath("data"), "ishiku"),
  ensure_installed = {},
  auto_install = false,
  auto_start = true,
  sync_install = false,
  prefer_git = vim.fn.has("win32") == 1,
  max_concurrent_installers = 4,
  registries = {
    "github:yuchanns/ishiku-registry",
  },
  parser_aliases = {},
  textobjects = {
    select = {
      enable = false,
      lookahead = false,
      lookbehind = false,
      selection_modes = {},
      include_surrounding_whitespace = false,
      keymaps = {},
    },
    move = {
      enable = false,
      set_jumps = true,
      goto_next_start = {},
      goto_next_end = {},
      goto_previous_start = {},
      goto_previous_end = {},
      goto_next = {},
      goto_previous = {},
    },
    swap = {
      enable = false,
      swap_next = {},
      swap_previous = {},
    },
    lsp_interop = {
      enable = false,
      floating_preview_opts = {},
      peek_definition_code = {},
    },
    repeatable_move = {
      enable = false,
      repeat_last_move = nil,
      repeat_last_move_opposite = nil,
      repeat_last_move_next = nil,
      repeat_last_move_previous = nil,
      builtin_f = nil,
      builtin_F = nil,
      builtin_t = nil,
      builtin_T = nil,
    },
    incremental_selection = {
      enable = false,
      keymaps = {
        init_selection = nil,
        node_incremental = nil,
        scope_incremental = nil,
        node_decremental = nil,
      },
    },
  },
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
