local state = require("ishiku.state")
local util = require("ishiku.util")
local Package = require("ishiku.package")
local settings = require("ishiku.settings")

local M = {}

local lockfile
local normalized_specs

local function parse_registry_source(source)
  if not vim.startswith(source, "github:") then
    error(("Unsupported registry source %q. Only github:<owner>/<repo> is supported."):format(source))
  end

  local repo = source:sub(#"github:" + 1)
  local owner, name = repo:match("^([^/]+)/([^/]+)$")
  if not owner or not name then
    error(("Invalid registry source: %s"):format(source))
  end

  return {
    kind = "path",
    repo = repo,
    url = ("https://github.com/%s.git"):format(repo),
    path = util.joinpath(state.registries_dir(), ("%s__%s"):format(owner, name)),
  }
end

local function ensure_registry_checkout(source)
  local parsed = parse_registry_source(source)
  if util.exists(parsed.path) then
    return parsed.path
  end

  if vim.fn.executable("git") ~= 1 then
    error(("git is required to fetch registry %s"):format(source))
  end

  state.ensure()
  local result = util.system_sync({ "git", "clone", parsed.url, parsed.path, "--filter=blob:none" })
  if result.code ~= 0 then
    error(("Failed to clone registry %s: %s"):format(source, result.stderr ~= "" and result.stderr or result.stdout))
  end
  return parsed.path
end

function M.refresh()
  local refreshed = {}
  for _, source in ipairs(settings.current.registries or {}) do
    local parsed = parse_registry_source(source)
    local path = ensure_registry_checkout(source)
    local result = util.system_sync({ "git", "-C", path, "pull", "--ff-only" })
    if result.code ~= 0 then
      error(("Failed to update registry %s: %s"):format(source, result.stderr ~= "" and result.stderr or result.stdout))
    end
    table.insert(refreshed, source)
  end
  lockfile = nil
  normalized_specs = nil
  return refreshed
end

local function load_lockfile()
  if not lockfile then
    lockfile = {}
    local loaded = false
    for _, registry_dir in ipairs(settings.current.registries or {}) do
      local path = util.joinpath(ensure_registry_checkout(registry_dir), "lockfile.json")
      local data = util.read_json(path)
      if data then
        lockfile = vim.tbl_deep_extend("force", lockfile, data)
        loaded = true
      end
    end
    if not loaded then
      error("No ishiku registry lockfile found. Configure `registries` to point to a valid ishiku-registry checkout.")
    end
  end
  return lockfile
end

local function normalize_spec(lang, parser)
  return {
    name = lang,
    filetype = parser.filetype or lang,
    maintainers = parser.maintainers or {},
    experimental = parser.experimental or false,
    source = {
      type = "git",
      url = parser.install_info.url,
      revision = parser.install_info.revision,
      branch = parser.install_info.branch,
      location = parser.install_info.location,
    },
    build = {
      files = parser.install_info.files,
      generate = parser.install_info.requires_generate_from_grammar or false,
      generate_requires_npm = parser.install_info.generate_requires_npm or false,
      use_makefile = parser.install_info.use_makefile or false,
      cxx_standard = parser.install_info.cxx_standard,
    },
  }
end

local function specs()
  if normalized_specs then
    return normalized_specs
  end

  normalized_specs = {}
  local loaded = false
  for _, registry_dir in ipairs(settings.current.registries or {}) do
    local parser_file = util.joinpath(ensure_registry_checkout(registry_dir), "registry", "parsers.lua")
    if util.exists(parser_file) then
      local chunk = assert(loadfile(parser_file))
      local module = chunk()
      local parser_list = module.list or module
      for lang, parser in pairs(parser_list) do
        normalized_specs[lang] = normalize_spec(lang, parser)
      end
      loaded = true
    end
  end

  if not loaded then
    error("No ishiku registry found. Configure `registries` to point to a valid ishiku-registry checkout.")
  end
  return normalized_specs
end

function M.get(lang)
  return specs()[lang]
end

function M.get_package(lang)
  local spec = M.get(lang)
  if not spec then
    error(("Unknown parser: %s"):format(lang))
  end
  return Package:new(lang, spec, M, require("ishiku.installer"))
end

function M.has(lang)
  return M.get(lang) ~= nil
end

function M.names()
  local names = vim.tbl_keys(specs())
  table.sort(names)
  return names
end

function M.all()
  return specs()
end

local function version_keys()
  local version = vim.version()
  return {
    ("nvim-%d.%d.%d"):format(version.major, version.minor, version.patch),
    ("nvim-%d.%d"):format(version.major, version.minor),
    ("nvim-%d"):format(version.major),
    "default",
  }
end

local function resolve_revision(info)
  if type(info) ~= "table" then
    return nil
  end

  if type(info.revision) == "string" then
    return info.revision
  end

  local revisions = info.revisions or info.revision
  if type(revisions) ~= "table" then
    return nil
  end

  for _, key in ipairs(version_keys()) do
    local revision = revisions[key]
    if type(revision) == "string" and revision ~= "" then
      return revision
    end
  end

  return nil
end

function M.locked_revision(lang)
  local parser = assert(M.get(lang), ("Unknown parser: %s"):format(lang))
  if parser.source.revision then
    return parser.source.revision
  end
  local revision = resolve_revision(load_lockfile()[lang])
  if revision then
    return revision
  end
  return parser.source.branch
end

function M.outdated(lang)
  if not state.is_installed(lang) then
    return false
  end
  local expected = M.locked_revision(lang)
  if not expected then
    return false
  end
  return state.installed_revision(lang) ~= expected
end

function M.installed()
  local installed = {}
  for _, lang in ipairs(M.names()) do
    if state.is_installed(lang) then
      table.insert(installed, lang)
    end
  end
  return installed
end

function M.installed_packages()
  local packages = {}
  for _, lang in ipairs(M.installed()) do
    table.insert(packages, M.get_package(lang))
  end
  return packages
end

return M
