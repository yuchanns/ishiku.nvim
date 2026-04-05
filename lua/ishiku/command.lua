local installer = require("ishiku.installer")
local log = require("ishiku.log")
local registry = require("ishiku.registry")
local ui = require("ishiku.ui")

local M = {}

local created = false

local function complete_registry(arg_lead)
  return vim.tbl_filter(function(item)
    return vim.startswith(item, arg_lead)
  end, registry.names())
end

local function complete_installed(arg_lead)
  return vim.tbl_filter(function(item)
    return vim.startswith(item, arg_lead)
  end, registry.installed())
end

function M.register()
  if created then
    return
  end
  created = true

  vim.api.nvim_create_user_command("Ishiku", function()
    ui.open()
  end, {
    desc = "Open ishiku parser manager UI.",
    nargs = 0,
  })

  vim.api.nvim_create_user_command("IshikuInstall", function(opts)
    installer.install_many(opts.fargs, {})
  end, {
    desc = "Install one or more treesitter parsers.",
    nargs = "+",
    complete = complete_registry,
  })

  vim.api.nvim_create_user_command("IshikuUpdate", function(opts)
    local args = opts.fargs
    if #args == 0 then
      args = registry.installed()
    end
    installer.update(args)
  end, {
    desc = "Update installed treesitter parsers.",
    nargs = "*",
    complete = complete_installed,
  })

  vim.api.nvim_create_user_command("IshikuUninstall", function(opts)
    for _, lang in ipairs(opts.fargs) do
      installer.uninstall(lang)
    end
  end, {
    desc = "Uninstall one or more treesitter parsers.",
    nargs = "+",
    complete = complete_installed,
  })

  vim.api.nvim_create_user_command("IshikuInfo", function()
    local installed = registry.installed()
    local lines = {}
    for _, lang in ipairs(registry.names()) do
      local mark = vim.tbl_contains(installed, lang) and "[installed]" or "[missing]"
      if registry.outdated(lang) then
        mark = "[outdated]"
      end
      table.insert(lines, ("%s %s"):format(mark, lang))
    end
    vim.cmd("new")
    local bufnr = vim.api.nvim_get_current_buf()
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].swapfile = false
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end, {
    desc = "Show ishiku parser installation status.",
    nargs = 0,
  })

  vim.api.nvim_create_user_command("IshikuLog", function()
    log.open()
  end, {
    desc = "Open ishiku install log.",
    nargs = 0,
  })

  vim.api.nvim_create_user_command("IshikuRegistryUpdate", function()
    local refreshed = registry.refresh()
    vim.notify(("[ishiku] Updated %d registries"):format(#refreshed))
  end, {
    desc = "Update ishiku registries.",
    nargs = 0,
  })
end

return M
