local command = require("ishiku.command")
local installer = require("ishiku.installer")
local query_compat = require("ishiku.query_compat")
local registry = require("ishiku.registry")
local settings = require("ishiku.settings")
local state = require("ishiku.state")
local textobjects = require("ishiku.textobjects")
local util = require("ishiku.util")

local M = {}

M.has_setup = false

local function assert_supported_nvim()
  if vim.fn.has("nvim-0.12") == 0 then
    error("ishiku.nvim requires Neovim 0.12+.")
  end
end

local function start_treesitter(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local bt = vim.bo[bufnr].buftype
  if bt ~= "" and bt ~= "acwrite" then
    return
  end

  local ft = vim.bo[bufnr].filetype
  if ft == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(ft)
  if not lang or lang == "" then
    return
  end

  pcall(vim.treesitter.start, bufnr, lang)
end

local function setup_auto_start()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
    group = vim.api.nvim_create_augroup("ishiku-auto-start", { clear = true }),
    callback = function(args)
      start_treesitter(args.buf)
    end,
  })

  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      start_treesitter(bufnr)
    end
  end)
end

local function setup_auto_install()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ishiku-auto-install", { clear = true }),
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      if ft == "" then
        return
      end
      local lang = vim.treesitter.language.get_lang(ft)
      if not lang then
        return
      end
      if state.is_installed(lang) then
        return
      end
      installer.install(lang, {})
    end,
  })
end

function M.setup(opts)
  assert_supported_nvim()
  settings.set(opts or {})
  state.ensure()
  util.ensure_runtimepath(settings.current.install_root_dir)
  query_compat.register()
  registry.activate()
  textobjects.setup(settings.current.textobjects)
  command.register()

  if settings.current.auto_install then
    setup_auto_install()
  end

  if settings.current.auto_start then
    setup_auto_start()
  end

  local ensure_installed = settings.current.ensure_installed
  if ensure_installed and #ensure_installed > 0 then
    vim.schedule(function()
      installer.ensure_installed(ensure_installed)
    end)
  end

  M.has_setup = true
end

return M
