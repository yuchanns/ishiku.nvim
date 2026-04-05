---@alias IshikuTextObjects.SelectionMode 'v'|'V'|'\22'

local default_config = {
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
}

local config = vim.deepcopy(default_config)

local M = {}

function M.update(cfg)
  config = vim.tbl_deep_extend('force', config, cfg or {})
end

setmetatable(M, {
  __index = function(_, k)
    return config[k]
  end,
})

return M
