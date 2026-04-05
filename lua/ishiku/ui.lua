local installer = require("ishiku.installer")
local log = require("ishiku.log")
local registry = require("ishiku.registry")
local receipt = require("ishiku.receipt")
local settings = require("ishiku.settings")
local state = require("ishiku.state")

require("ishiku.ui.colors")

local M = {}

local buffers = {}

local HEADER_LINES = 5
local STATUS_LABELS = {
  pending = "pending",
  failed = "failed",
  outdated = "outdated",
  installed = "installed",
  available = "available",
}

local function status_rank(entry)
  if entry.pending then
    return 1
  end
  if entry.failed then
    return 2
  end
  if entry.installed and entry.outdated then
    return 3
  end
  if entry.installed then
    return 4
  end
  return 5
end

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

  table.sort(entries, function(a, b)
    local left = status_rank(a)
    local right = status_rank(b)
    if left ~= right then
      return left < right
    end
    return a.lang < b.lang
  end)

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

local function entry_status(entry)
  if entry.pending then
    return STATUS_LABELS.pending, "IshikuHighlight"
  end
  if entry.failed then
    return STATUS_LABELS.failed, "IshikuError"
  end
  if entry.installed and entry.outdated then
    return STATUS_LABELS.outdated, "IshikuWarning"
  end
  if entry.installed then
    return STATUS_LABELS.installed, "IshikuMuted"
  end
  return STATUS_LABELS.available, "IshikuMuted"
end

local function collect_stats(entries)
  local stats = {
    total = #entries,
    installed = 0,
    pending = 0,
    outdated = 0,
    failed = 0,
  }

  for _, entry in ipairs(entries) do
    if entry.installed then
      stats.installed = stats.installed + 1
    end
    if entry.pending then
      stats.pending = stats.pending + 1
    end
    if entry.installed and entry.outdated then
      stats.outdated = stats.outdated + 1
    end
    if entry.failed then
      stats.failed = stats.failed + 1
    end
  end

  return stats
end

local function format_stats(stats)
  return table.concat({
    ("%d total"):format(stats.total),
    ("%d installed"):format(stats.installed),
    ("%d outdated"):format(stats.outdated),
    ("%d pending"):format(stats.pending),
    ("%d failed"):format(stats.failed),
  }, "  •  ")
end

local function render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local entries = line_entries()
  buffers[bufnr] = entries

  local stats = collect_stats(entries)
  local longest_lang = 0
  for _, entry in ipairs(entries) do
    longest_lang = math.max(longest_lang, #entry.lang)
  end

  local lines = {
    " ishiku.nvim ",
    format_stats(stats),
    " ",
    "  i install    u update    X uninstall    <CR> details    l log    g refresh    q close",
    " ",
  }

  local highlights = {
    { line = 0, start_col = 0, end_col = #lines[1], group = "IshikuHeader" },
    { line = 1, start_col = 0, end_col = #lines[2], group = "IshikuMuted" },
    { line = 3, start_col = 0, end_col = #lines[4], group = "IshikuHeaderSecondary" },
  }

  for _, entry in ipairs(entries) do
    local status, status_hl = entry_status(entry)
    local icon = entry_icon(entry)
    local row = #lines
    local lang = entry.lang .. string.rep(" ", longest_lang - #entry.lang)
    local status_block = ("[%s]"):format(status)
    local detail = ""

    if entry.installed and entry.outdated then
      detail = "locked revision differs from installed parser"
    elseif entry.pending then
      detail = "install or update in progress"
    elseif entry.failed then
      detail = "last install failed"
    elseif entry.installed then
      detail = "installed and ready"
    else
      detail = "available for installation"
    end

    local line = ("  %s  %s  %s  %s"):format(icon, lang, status_block, detail)
    table.insert(lines, line)

    table.insert(highlights, { line = row, start_col = 2, end_col = 5, group = status_hl })
    table.insert(highlights, { line = row, start_col = 5, end_col = 5 + #lang + 2, group = "IshikuHeading" })

    local status_start = 5 + #lang + 2
    local status_end = status_start + #status_block + 2
    table.insert(highlights, { line = row, start_col = status_start, end_col = status_end, group = status_hl })

    local detail_start = status_end + 2
    table.insert(highlights, { line = row, start_col = detail_start, end_col = #line, group = "IshikuMuted" })
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
  for _, item in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, -1, item.group, item.line, item.start_col, item.end_col)
  end
  vim.bo[bufnr].modifiable = false
end

local function current_lang(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local entry = buffers[bufnr] and buffers[bufnr][cursor - HEADER_LINES]
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
  local detail_buf = vim.api.nvim_create_buf(false, true)

  local width = math.min(math.floor(vim.o.columns * 0.55), 90)
  local height = 12 + (failure and 1 or 0) + (data and 2 or 0)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  vim.api.nvim_open_win(detail_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = settings.current.ui.border,
    title = " ishiku package ",
    title_pos = "center",
    style = "minimal",
  })

  vim.bo[detail_buf].buftype = "nofile"
  vim.bo[detail_buf].bufhidden = "wipe"
  vim.bo[detail_buf].swapfile = false
  vim.bo[detail_buf].modifiable = false
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

  vim.bo[detail_buf].modifiable = true
  vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
  vim.bo[detail_buf].modifiable = false
  vim.api.nvim_set_option_value("winhl", "NormalFloat:IshikuNormal,FloatBorder:IshikuHighlight", { win = vim.api.nvim_get_current_win() })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = detail_buf, silent = true })
end

function M.open()
  local bufnr = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * settings.current.ui.width)
  local height = math.floor(vim.o.lines * settings.current.ui.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = settings.current.ui.border,
    title = " ishiku ",
    title_pos = "center",
    style = "minimal",
  })

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "ishiku"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.wo[winid].cursorline = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].wrap = false
  vim.wo[winid].winhighlight = table.concat({
    "NormalFloat:IshikuNormal",
    "FloatBorder:IshikuHighlight",
    "CursorLine:IshikuCursorLine",
  }, ",")

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
