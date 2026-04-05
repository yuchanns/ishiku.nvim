local settings = require("ishiku.settings")
local util = require("ishiku.util")

local M = {}

function M.install_root_dir()
  return settings.current.install_root_dir
end

function M.parser_dir()
  local path = util.joinpath(M.install_root_dir(), "parser")
  util.mkdirp(path)
  return path
end

function M.parser_info_dir()
  local path = util.joinpath(M.install_root_dir(), "parser-info")
  util.mkdirp(path)
  return path
end

function M.cache_dir()
  local path = util.joinpath(M.install_root_dir(), "cache")
  util.mkdirp(path)
  return path
end

function M.staging_dir()
  local path = util.joinpath(M.install_root_dir(), "staging")
  util.mkdirp(path)
  return path
end

function M.receipts_dir()
  local path = util.joinpath(M.install_root_dir(), "receipts")
  util.mkdirp(path)
  return path
end

function M.logs_dir()
  local path = util.joinpath(M.install_root_dir(), "logs")
  util.mkdirp(path)
  return path
end

function M.registries_dir()
  local path = util.joinpath(M.install_root_dir(), "registries")
  util.mkdirp(path)
  return path
end

function M.ensure()
  util.mkdirp(M.install_root_dir())
  M.parser_dir()
  M.parser_info_dir()
  M.cache_dir()
  M.staging_dir()
  M.receipts_dir()
  M.logs_dir()
  M.registries_dir()
end

function M.parser_path(lang)
  return util.joinpath(M.parser_dir(), ("%s.so"):format(lang))
end

function M.revision_path(lang)
  return util.joinpath(M.parser_info_dir(), ("%s.revision"):format(lang))
end

function M.receipt_path(lang)
  return util.joinpath(M.receipts_dir(), ("%s.json"):format(lang))
end

function M.log_path()
  return util.joinpath(M.logs_dir(), "ishiku.log")
end

function M.staging_path(lang)
  return util.joinpath(M.staging_dir(), ("%s-%s"):format(lang, tostring(vim.uv.hrtime())))
end

function M.is_installed(lang)
  return util.exists(M.parser_path(lang))
end

function M.installed_revision(lang)
  local path = M.revision_path(lang)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  return vim.fn.readfile(path)[1]
end

function M.write_revision(lang, revision)
  util.write_lines(M.revision_path(lang), { revision or "" })
end

function M.clear(lang)
  vim.fn.delete(M.parser_path(lang))
  vim.fn.delete(M.revision_path(lang))
  vim.fn.delete(M.receipt_path(lang))
end

return M
