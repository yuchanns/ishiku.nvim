local command = require("ishiku.command")
local installer = require("ishiku.installer")
local settings = require("ishiku.settings")
local state = require("ishiku.state")
local util = require("ishiku.util")

local M = {}

M.has_setup = false

local function assert_supported_nvim()
  if vim.fn.has("nvim-0.12") == 0 then
    error("ishiku.nvim requires Neovim 0.12+.")
  end
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
  command.register()

  if settings.current.auto_install then
    setup_auto_install()
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
