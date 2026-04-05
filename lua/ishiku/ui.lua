local installer = require("ishiku.installer")
local log = require("ishiku.log")
local registry = require("ishiku.registry")
local receipt = require("ishiku.receipt")
local settings = require("ishiku.settings")
local state = require("ishiku.state")

local M = {}

local buffers = {}

local function line_entries()
  local entries = {}
  for _, lang in ipairs(registry.names()) do
    table.insert(entries, {
      lang = lang,
      installed = state.is_installed(lang),
      pending = installer.is_pending(lang),
      outdated = registry.outdated(lang),
      failed = installer.failure(lang) ~= nil,
    })
  end
  return entries
end

local function entry_icon(entry)
  local icons = settings.current.ui.icons
  if entry.pending then
    return icons.pending
  end
  if entry.failed then
    return icons.failed
  end
  if entry.installed and entry.outdated then
    return icons.outdated
  end
  if entry.installed then
    return icons.installed
  end
  return icons.uninstalled
end

local function render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local entries = line_entries()
  buffers[bufnr] = entries

  local lines = {
    "ishiku.nvim",
    "",
    "i install  u update  X uninstall  <CR> details  l log  g refresh  q quit",
    "",
  }

  for _, entry in ipairs(entries) do
    local suffix = ""
    if entry.installed and entry.outdated then
      suffix = " (outdated)"
    elseif entry.pending then
      suffix = " (pending)"
    end
    table.insert(lines, ("%s %s%s"):format(entry_icon(entry), entry.lang, suffix))
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

local function current_lang(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local entry = buffers[bufnr] and buffers[bufnr][cursor - 4]
  return entry and entry.lang or nil
end

local function refresh_current()
  local bufnr = vim.api.nvim_get_current_buf()
  render(bufnr)
end

local function open_details(bufnr)
  local lang = current_lang(bufnr)
  if not lang then
    return
  end

  local spec = registry.get(lang)
  local data = receipt.read(lang)
  local failure = installer.failure(lang)
  vim.cmd("vnew")
  local detail_buf = vim.api.nvim_get_current_buf()
  vim.bo[detail_buf].buftype = "nofile"
  vim.bo[detail_buf].bufhidden = "wipe"
  vim.bo[detail_buf].swapfile = false
  vim.bo[detail_buf].filetype = "lua"

  local lines = {
    ("name = %q"):format(lang),
    ("installed = %s"):format(tostring(state.is_installed(lang))),
    ("outdated = %s"):format(tostring(registry.outdated(lang))),
    ("locked_revision = %q"):format(registry.locked_revision(lang) or ""),
    ("source_url = %q"):format(spec.source.url),
    ("filetype = %q"):format(spec.filetype),
    ("generate = %s"):format(tostring(spec.build.generate)),
  }

  if data then
    table.insert(lines, ("installed_revision = %q"):format(data.revision or ""))
    table.insert(lines, ("installed_at = %s"):format(tostring(data.installed_at)))
  end
  if failure then
    table.insert(lines, ("last_error = %q"):format(failure))
  end

  vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
end

function M.open()
  local bufnr = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * settings.current.ui.width)
  local height = math.floor(vim.o.lines * settings.current.ui.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = settings.current.ui.border,
    style = "minimal",
  })

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "ishiku"

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true })
  end

  map("q", "<cmd>close<cr>")
  map("g", refresh_current)
  map("l", function()
    log.open()
  end)
  map("<CR>", function()
    open_details(bufnr)
  end)
  map("i", function()
    local lang = current_lang(bufnr)
    if not lang then
      return
    end
    installer.install(lang, {}, function()
      render(bufnr)
    end)
    render(bufnr)
  end)
  map("u", function()
    local lang = current_lang(bufnr)
    if not lang then
      return
    end
    installer.update({ lang }, function()
      render(bufnr)
    end)
    render(bufnr)
  end)
  map("X", function()
    local lang = current_lang(bufnr)
    if not lang then
      return
    end
    installer.uninstall(lang)
    render(bufnr)
  end)

  render(bufnr)
end

return M
