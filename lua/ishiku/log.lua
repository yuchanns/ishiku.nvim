local state = require("ishiku.state")
local settings = require("ishiku.settings")

require("ishiku.ui.colors")

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

local function read_lines()
  local path = M.path()
  if vim.fn.filereadable(path) ~= 1 then
    return { "No log entries yet." }
  end

  local lines = vim.fn.readfile(path)
  if vim.tbl_isempty(lines) then
    return { "No log entries yet." }
  end
  return lines
end

local function render(bufnr)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, read_lines())
  vim.bo[bufnr].modifiable = false
end

function M.open()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(math.floor(vim.o.columns * 0.78), 120)
  local height = math.min(math.floor(vim.o.lines * 0.72), math.max(vim.o.lines - 6, 12))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = settings.current.ui.border,
    title = " ishiku log ",
    title_pos = "center",
    footer = " g refresh  q close ",
    footer_pos = "right",
    style = "minimal",
  })

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "log"
  vim.bo[bufnr].buflisted = false

  vim.wo[winid].wrap = false
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].cursorline = false
  vim.wo[winid].winhighlight = table.concat({
    "NormalFloat:IshikuNormal",
    "FloatBorder:IshikuHighlight",
  }, ",")

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr, silent = true })
  vim.keymap.set("n", "g", function()
    render(bufnr)
  end, { buffer = bufnr, silent = true })

  render(bufnr)
  vim.api.nvim_win_set_cursor(winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
end

return M
