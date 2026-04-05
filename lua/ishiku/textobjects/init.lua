local config = require('ishiku.textobjects.config')
local incremental_selection = require('ishiku.textobjects.incremental_selection')
local lsp_interop = require('ishiku.textobjects.lsp_interop')
local move = require('ishiku.textobjects.move')
local repeatable_move = require('ishiku.textobjects.repeatable_move')
local select = require('ishiku.textobjects.select')
local swap = require('ishiku.textobjects.swap')

local M = {}

local function has_key(lhs)
  return type(lhs) == 'string' and lhs ~= ''
end

local function parse_mapping(rhs, default_query_group)
  if type(rhs) == 'string' then
    return rhs, default_query_group
  end
  if vim.islist(rhs) then
    return rhs, default_query_group
  end
  if type(rhs) ~= 'table' then
    return nil, default_query_group
  end

  local query_group = rhs.query_group or default_query_group
  if rhs.query ~= nil then
    return rhs.query, query_group
  end
  if rhs.capture ~= nil then
    return rhs.capture, query_group
  end
  if rhs.queries ~= nil then
    return rhs.queries, query_group
  end
  if rhs[1] ~= nil then
    if vim.islist(rhs) then
      return rhs, query_group
    end
    return rhs[1], query_group
  end

  return nil, query_group
end

local function map(lhs, modes, rhs, desc)
  if not has_key(lhs) then
    return
  end
  vim.keymap.set(modes, lhs, rhs, { silent = true, desc = desc })
end

local function setup_select(opts)
  if not opts.enable then
    return
  end
  for lhs, rhs in pairs(opts.keymaps or {}) do
    local query, query_group = parse_mapping(rhs, 'textobjects')
    if query then
      map(lhs, { 'x', 'o' }, function()
        select.select_textobject(query, query_group)
      end, 'Ishiku Textobject Select')
    end
  end
end

local function setup_move(opts)
  if not opts.enable then
    return
  end

  local specs = {
    { key = 'goto_next_start', fn = move.goto_next_start, desc = 'Ishiku Textobject Next Start' },
    { key = 'goto_next_end', fn = move.goto_next_end, desc = 'Ishiku Textobject Next End' },
    { key = 'goto_previous_start', fn = move.goto_previous_start, desc = 'Ishiku Textobject Previous Start' },
    { key = 'goto_previous_end', fn = move.goto_previous_end, desc = 'Ishiku Textobject Previous End' },
    { key = 'goto_next', fn = move.goto_next, desc = 'Ishiku Textobject Next' },
    { key = 'goto_previous', fn = move.goto_previous, desc = 'Ishiku Textobject Previous' },
  }

  for _, spec in ipairs(specs) do
    for lhs, rhs in pairs(opts[spec.key] or {}) do
      local query, query_group = parse_mapping(rhs, 'textobjects')
      if query then
        map(lhs, { 'n', 'x', 'o' }, function()
          spec.fn(query, query_group)
        end, spec.desc)
      end
    end
  end
end

local function setup_swap(opts)
  if not opts.enable then
    return
  end

  for lhs, rhs in pairs(opts.swap_next or {}) do
    local query, query_group = parse_mapping(rhs, 'textobjects')
    if query then
      map(lhs, 'n', function()
        swap.swap_next(query, query_group)
      end, 'Ishiku Textobject Swap Next')
    end
  end

  for lhs, rhs in pairs(opts.swap_previous or {}) do
    local query, query_group = parse_mapping(rhs, 'textobjects')
    if query then
      map(lhs, 'n', function()
        swap.swap_previous(query, query_group)
      end, 'Ishiku Textobject Swap Previous')
    end
  end
end


local function setup_lsp_interop(opts)
  if not opts.enable then
    return
  end

  for lhs, rhs in pairs(opts.peek_definition_code or {}) do
    local query, query_group = parse_mapping(rhs, 'textobjects')
    if query then
      map(lhs, { 'n', 'x', 'o' }, function()
        lsp_interop.peek_definition_code(query, query_group)
      end, 'Ishiku Textobject Peek Definition')
    end
  end
end

local function setup_repeatable_move(opts)
  if not opts.enable then
    return
  end

  map(opts.repeat_last_move, { 'n', 'x', 'o' }, repeatable_move.repeat_last_move, 'Ishiku Repeat Move')
  map(opts.repeat_last_move_opposite, { 'n', 'x', 'o' }, repeatable_move.repeat_last_move_opposite, 'Ishiku Repeat Move Opposite')
  map(opts.repeat_last_move_next, { 'n', 'x', 'o' }, repeatable_move.repeat_last_move_next, 'Ishiku Repeat Move Next')
  map(opts.repeat_last_move_previous, { 'n', 'x', 'o' }, repeatable_move.repeat_last_move_previous, 'Ishiku Repeat Move Previous')

  if has_key(opts.builtin_f) then
    vim.keymap.set({ 'n', 'x', 'o' }, opts.builtin_f, repeatable_move.builtin_f_expr, { expr = true, silent = true, desc = 'Ishiku Repeatable f' })
  end
  if has_key(opts.builtin_F) then
    vim.keymap.set({ 'n', 'x', 'o' }, opts.builtin_F, repeatable_move.builtin_F_expr, { expr = true, silent = true, desc = 'Ishiku Repeatable F' })
  end
  if has_key(opts.builtin_t) then
    vim.keymap.set({ 'n', 'x', 'o' }, opts.builtin_t, repeatable_move.builtin_t_expr, { expr = true, silent = true, desc = 'Ishiku Repeatable t' })
  end
  if has_key(opts.builtin_T) then
    vim.keymap.set({ 'n', 'x', 'o' }, opts.builtin_T, repeatable_move.builtin_T_expr, { expr = true, silent = true, desc = 'Ishiku Repeatable T' })
  end
end

function M.setup(opts)
  config.update(opts or {})
  setup_select(config.select)
  setup_move(config.move)
  setup_swap(config.swap)
  setup_lsp_interop(config.lsp_interop)
  setup_repeatable_move(config.repeatable_move)
  incremental_selection.setup(config.incremental_selection)
end

return M
