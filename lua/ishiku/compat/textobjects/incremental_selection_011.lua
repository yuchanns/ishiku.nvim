local api = vim.api
local select = require("ishiku.textobjects._select")
local shared = require("ishiku.textobjects.shared")
local ts_range = vim.treesitter._range or require("ishiku.textobjects._range")

local M = {}

local function has_key(lhs)
  return type(lhs) == "string" and lhs ~= ""
end

local function in_visual_mode()
  local mode = api.nvim_get_mode().mode
  return mode == "v" or mode == "V" or mode == "\22"
end

local function get_selection()
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  if pos1[2] > pos2[2] or (pos1[2] == pos2[2] and pos1[3] > pos2[3]) then
    pos1, pos2 = pos2, pos1
  end
  local range = { pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3] }
  if range[4] == #vim.fn.getline(range[3] + 1) + 1 then
    range[3] = range[3] + 1
    range[4] = 0
  end
  return range
end

local function update_selection(range)
  local start_row, start_col, end_row, end_col = ts_range.unpack4(range)
  local mode = api.nvim_get_mode().mode
  if mode ~= "v" then
    vim.cmd.normal({ "v", bang = true })
  end
  if end_col == 0 then
    end_row = end_row - 1
    end_col = #api.nvim_buf_get_lines(0, end_row, end_row + 1, true)[1] + 1
  end
  local end_col_offset = vim.o.selection == "exclusive" and 0 or 1
  end_col = end_col - end_col_offset
  api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  vim.cmd("normal! o")
  api.nvim_win_set_cursor(0, { end_row + 1, end_col })
end

local function ensure_visual_selection()
  if not in_visual_mode() then
    vim.cmd.normal({ "v", bang = true })
  end
end

function M.init_selection()
  ensure_visual_selection()
  select.select_parent(vim.v.count1)
end

function M.node_incremental()
  if not in_visual_mode() then
    M.init_selection()
    return
  end
  select.select_parent(vim.v.count1)
end

function M.node_decremental()
  if not in_visual_mode() then
    return
  end
  select.select_child(vim.v.count1)
end

function M.scope_incremental()
  if not in_visual_mode() then
    M.init_selection()
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local range = get_selection()
  local current = ts_range.add_bytes(bufnr, range)

  local function filter(scope)
    return ts_range.contains(scope, current) and not ts_range.contains(current, scope)
  end

  local function score(scope)
    return -(scope[6] - scope[3])
  end

  local best = nil
  for _ = 1, vim.v.count1 do
    best = shared.find_best_range(bufnr, "@local.scope", "locals", filter, score)
    if not best then
      break
    end
    current = best
  end

  if best then
    update_selection(best)
  else
    select.select_parent(1)
  end
end

function M.setup(opts)
  if not opts.enable then
    return
  end
  local keymaps = opts.keymaps or {}
  if has_key(keymaps.init_selection) then
    vim.keymap.set({ "n", "x" }, keymaps.init_selection, M.init_selection, { silent = true, desc = "Ishiku Init Selection" })
  end
  if has_key(keymaps.node_incremental) then
    vim.keymap.set("x", keymaps.node_incremental, M.node_incremental, { silent = true, desc = "Ishiku Increment Selection" })
  end
  if has_key(keymaps.scope_incremental) then
    vim.keymap.set("x", keymaps.scope_incremental, M.scope_incremental, { silent = true, desc = "Ishiku Scope Selection" })
  end
  if has_key(keymaps.node_decremental) then
    vim.keymap.set("x", keymaps.node_decremental, M.node_decremental, { silent = true, desc = "Ishiku Decrement Selection" })
  end
end

return M
