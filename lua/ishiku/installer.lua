local log = require("ishiku.log")
local receipt = require("ishiku.receipt")
local registry = require("ishiku.registry")
local settings = require("ishiku.settings")
local state = require("ishiku.state")
local util = require("ishiku.util")

local M = {}

local active = {}
local queue = {}
local running = 0
local failures = {}

local function parser_lang_for_buf(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == "" then
    return nil
  end
  return vim.treesitter.language.get_lang(ft)
end

local function reattach(lang)
  local path = state.parser_path(lang)
  if not util.exists(path) then
    return
  end

  pcall(vim._ts_remove_language, lang)
  pcall(vim.treesitter.language.add, lang, { path = path })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if parser_lang_for_buf(buf) == lang then
      pcall(vim.treesitter.start, buf, lang)
    end
  end
end

local function has_cpp_files(files)
  for _, file in ipairs(files) do
    local ext = vim.fn.fnamemodify(file, ":e")
    if ext == "cc" or ext == "cpp" or ext == "cxx" then
      return true
    end
  end
  return false
end

local function compiler_args(spec, output_path, compiler)
  local files = spec.build.files
  if compiler:match("cl%.exe$") or compiler:match("cl$") then
    local args = { "/Fe:" .. output_path, "/Isrc", "-Os", "/std:c11", "/utf-8", "/LD" }
    vim.list_extend(args, files)
    return args
  end

  if compiler:match("zig%.exe$") or compiler:match("zig$") then
    local args = { "c++", "-o", output_path, "-lc", "-Isrc", "-Os", "-std=c11" }
    vim.list_extend(args, files)
    table.insert(args, util.is_macos() and "-bundle" or "-shared")
    if spec.build.cxx_standard then
      table.insert(args, ("-std=%s"):format(spec.build.cxx_standard))
    end
    if not util.is_windows() then
      table.insert(args, "-fPIC")
    end
    return args
  end

  local args = { "-o", output_path, "-I./src", "-Os", "-std=c11" }
  vim.list_extend(args, files)
  table.insert(args, util.is_macos() and "-bundle" or "-shared")
  if has_cpp_files(files) then
    if spec.build.cxx_standard then
      table.insert(args, ("-std=%s"):format(spec.build.cxx_standard))
    end
    table.insert(args, "-lstdc++")
  end
  if not util.is_windows() then
    table.insert(args, "-fPIC")
  end
  return args
end

local function system(cmd, opts, on_exit)
  log.command(cmd, opts)
  util.system(cmd, opts, function(result)
    log.result(result)
    on_exit(result)
  end)
end

local function run_steps(steps, on_done, index)
  index = index or 1
  local step = steps[index]
  if not step then
    on_done(true)
    return
  end

  step(function(success, err)
    if not success then
      on_done(false, err)
      return
    end
    run_steps(steps, on_done, index + 1)
  end)
end

local function finish_job(lang, success, err, callback)
  active[lang] = nil
  running = running - 1
  if success then
    failures[lang] = nil
    util.notify(("Installed parser %s"):format(lang))
  else
    failures[lang] = err or "unknown error"
    util.notify(("Failed to install %s: %s"):format(lang, err or "unknown error"), vim.log.levels.ERROR)
  end
  if callback then
    callback(success, err)
  end
  vim.schedule(M._drain)
end

local function promote(staging_parser_path, final_parser_path)
  vim.fn.mkdir(vim.fn.fnamemodify(final_parser_path, ":h"), "p")
  vim.fn.rename(staging_parser_path, final_parser_path)
end

local function tarball_url(source, revision, lang)
  local url = source.url:gsub("%.git$", "")
  if url:find("github.com", 1, true) then
    return ("%s/archive/%s.tar.gz"):format(url, revision), ("%s-%s"):format(url:match("[^/]+$"), revision:gsub("^v", ""))
  end
  if url:find("gitlab.com", 1, true) then
    return ("%s/-/archive/%s/tree-sitter-%s-%s.tar.gz"):format(url, revision, lang, revision), ("tree-sitter-%s-%s"):format(lang, revision)
  end
end

local function fetch_tarball(lang, spec, revision, staging_root, checkout_dir, callback)
  local archive_path = util.joinpath(staging_root, "source.tar.gz")
  local url, extracted_dir_name = tarball_url(spec.source, revision, lang)
  if not url then
    callback(false, "tarball download is not supported for this source")
    return
  end

  system({ "curl", "--silent", "--show-error", "-L", url, "--output", archive_path }, {}, function(download)
    if download.code ~= 0 then
      callback(false, download.stderr ~= "" and download.stderr or download.stdout)
      return
    end

    system({ "tar", "-xzf", archive_path, "-C", staging_root }, {}, function(extract)
      if extract.code ~= 0 then
        callback(false, extract.stderr ~= "" and extract.stderr or extract.stdout)
        return
      end
      local extracted = util.joinpath(staging_root, extracted_dir_name)
      if not util.exists(extracted) then
        callback(false, ("unable to locate extracted source directory: %s"):format(extracted_dir_name))
        return
      end
      vim.fn.rename(extracted, checkout_dir)
      vim.fn.delete(archive_path)
      callback(true)
    end)
  end)
end

local function fetch_git(spec, revision, checkout_dir, callback)
  system({ "git", "clone", spec.source.url, checkout_dir, "--filter=blob:none" }, {}, function(result)
    if result.code ~= 0 then
      callback(false, result.stderr ~= "" and result.stderr or result.stdout)
      return
    end

    system({ "git", "checkout", revision }, { cwd = checkout_dir }, function(checkout)
      if checkout.code ~= 0 then
        callback(false, checkout.stderr ~= "" and checkout.stderr or checkout.stdout)
        return
      end
      callback(true)
    end)
  end)
end

local function fetch_source(lang, spec, revision, staging_root, checkout_dir, callback)
  local can_use_tarball = not settings.current.prefer_git
    and vim.fn.executable("curl") == 1
    and vim.fn.executable("tar") == 1
    and tarball_url(spec.source, revision, lang) ~= nil

  if can_use_tarball then
    fetch_tarball(lang, spec, revision, staging_root, checkout_dir, function(success, err)
      if success then
        callback(true)
        return
      end
      log.append(("tarball fetch failed for %s, falling back to git: %s"):format(lang, err))
      if vim.fn.executable("git") ~= 1 then
        callback(false, err)
        return
      end
      fetch_git(spec, revision, checkout_dir, callback)
    end)
    return
  end

  if vim.fn.executable("git") ~= 1 then
    callback(false, "`git` is required to install parser sources.")
    return
  end
  fetch_git(spec, revision, checkout_dir, callback)
end

local function compile(spec, compiler, build_dir, staging_parser_path, callback)
  if spec.build.use_makefile and not util.is_windows() then
    local make = util.select_executable({ "gmake", "make" })
    if make then
      local makefile = util.joinpath(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h"), "scripts", "compile_parsers.makefile")
      if util.exists(makefile) then
        system({
          make,
          ("--makefile=%s"):format(makefile),
          ("CC=%s"):format(compiler),
          ("CXX_STANDARD=%s"):format(spec.build.cxx_standard or "c++14"),
          ("OUTPUT=%s"):format(staging_parser_path),
        }, { cwd = build_dir }, function(result)
          if result.code ~= 0 then
            callback(false, result.stderr ~= "" and result.stderr or result.stdout)
            return
          end
          callback(true)
        end)
        return
      end
    end
  end

  local args = compiler_args(spec, staging_parser_path, compiler)
  local cmd = { compiler, unpack(args) }
  system(cmd, { cwd = build_dir }, function(result)
    if result.code ~= 0 then
      callback(false, result.stderr ~= "" and result.stderr or result.stdout)
      return
    end
    callback(true)
  end)
end

local function install_from_repo(lang, spec, opts, callback)
  local revision = registry.locked_revision(lang) or "master"
  local compiler = util.select_executable(settings.current.compilers)
  local staging_root = state.staging_path(lang)
  local checkout_dir = util.joinpath(staging_root, "source")
  local build_dir = checkout_dir
  local staging_parser_path = util.joinpath(staging_root, "parser.so")
  local final_parser_path = state.parser_path(lang)

  if not compiler then
    callback(false, "No supported C compiler found.")
    return
  end

  local source_root = vim.fn.expand(spec.source.url)
  local use_local_repo = vim.fn.isdirectory(source_root) == 1
  if use_local_repo then
    checkout_dir = source_root
    build_dir = source_root
  end

  if spec.source.location then
    build_dir = util.joinpath(build_dir, spec.source.location)
  end

  local steps = {}

  table.insert(steps, function(next_step)
    state.ensure()
    util.mkdirp(staging_root)
    if not use_local_repo then
      util.rmrf(checkout_dir)
    end
    next_step(true)
  end)

  if not use_local_repo then
    table.insert(steps, function(next_step)
      fetch_source(lang, spec, revision, staging_root, checkout_dir, next_step)
    end)
  end

  if spec.build.generate then
    table.insert(steps, function(next_step)
      if vim.fn.executable("tree-sitter") ~= 1 then
        next_step(false, "`tree-sitter` CLI is required for this parser.")
        return
      end
      if vim.fn.executable("node") ~= 1 then
        next_step(false, "`node` is required for parser generation.")
        return
      end
      next_step(true)
    end)

    if spec.build.generate_requires_npm then
      table.insert(steps, function(next_step)
        if vim.fn.executable("npm") ~= 1 then
          next_step(false, "`npm` is required for this parser.")
          return
        end
        system({ "npm", "install" }, { cwd = build_dir }, function(result)
          if result.code ~= 0 then
            next_step(false, result.stderr ~= "" and result.stderr or result.stdout)
            return
          end
          next_step(true)
        end)
      end)
    end

    table.insert(steps, function(next_step)
      local generate_args = { "generate", "--no-bindings" }
      system({ "tree-sitter", unpack(generate_args) }, { cwd = build_dir }, function(result)
        if result.code ~= 0 then
          next_step(false, result.stderr ~= "" and result.stderr or result.stdout)
          return
        end
        next_step(true)
      end)
    end)
  end

  table.insert(steps, function(next_step)
    compile(spec, compiler, build_dir, staging_parser_path, next_step)
  end)

  table.insert(steps, function(next_step)
    if util.exists(final_parser_path) then
      vim.fn.delete(final_parser_path)
    end
    promote(staging_parser_path, final_parser_path)
    state.write_revision(lang, revision)
    receipt.write(lang, {
      name = lang,
      revision = revision,
      installed_at = os.time(),
      source = {
        type = "git",
        url = spec.source.url,
        location = spec.source.location,
      },
      build = {
        files = spec.build.files,
        compiler = compiler,
        generate = spec.build.generate,
        generate_requires_npm = spec.build.generate_requires_npm,
      },
      artifacts = {
        state.parser_path(lang),
      },
    })
    reattach(lang)
    next_step(true)
  end)

  run_steps(steps, function(success, err)
    if not use_local_repo then
      util.rmrf(checkout_dir)
    end
    util.rmrf(staging_root)
    callback(success, err)
  end)
end

local function normalize_langs(langs)
  local result = {}
  for _, lang in ipairs(langs) do
    if lang == "all" then
      return registry.names()
    end
    table.insert(result, lang)
  end
  return result
end

function M.is_pending(lang)
  return active[lang] == true
end

function M.failure(lang)
  return failures[lang]
end

function M._drain()
  while running < settings.current.max_concurrent_installers and #queue > 0 do
    local job = table.remove(queue, 1)
    running = running + 1
    active[job.lang] = true
    util.notify(("Installing parser %s"):format(job.lang))
    install_from_repo(job.lang, job.spec, job.opts, function(success, err)
      finish_job(job.lang, success, err, job.callback)
    end)
  end
end

function M.install(lang, opts, callback)
  opts = opts or {}
  callback = callback or function() end

  if active[lang] then
    callback(false, ("Parser %s is already being installed."):format(lang))
    return
  end

  if not registry.has(lang) then
    callback(false, ("Unknown parser: %s"):format(lang))
    return
  end

  if state.is_installed(lang) and not opts.force then
    callback(true)
    return
  end

  table.insert(queue, {
    lang = lang,
    spec = registry.get(lang),
    opts = opts,
    callback = callback,
  })

  if settings.current.sync_install then
    local completed = false
    local original_callback = callback
    queue[#queue].callback = function(success, err)
      completed = true
      original_callback(success, err)
    end
    while not completed do
      M._drain()
      vim.wait(50)
    end
  else
    M._drain()
  end
end

function M.install_many(langs, opts, callback)
  langs = normalize_langs(langs)
  if settings.current.sync_install then
    for _, lang in ipairs(langs) do
      local done = false
      local ok = true
      local err
      M.install(lang, opts, function(success, failure)
        ok = success
        err = failure
        done = true
      end)
      if not done or not ok then
        if callback then
          callback(false, err)
        end
        return
      end
    end
    if callback then
      callback(true)
    end
    return
  end

  local remaining = #langs
  local failed = false
  local failure_error
  if remaining == 0 then
    if callback then
      callback(true)
    end
    return
  end

  for _, lang in ipairs(langs) do
    M.install(lang, opts, function(success, err)
      remaining = remaining - 1
      if not success and not failed then
        failed = true
        failure_error = err
      end
      if remaining == 0 and callback then
        callback(not failed, failure_error)
      end
    end)
  end
end

function M.update(langs, callback)
  local targets = normalize_langs(langs)
  local filtered = {}
  for _, lang in ipairs(targets) do
    if not state.is_installed(lang) or registry.outdated(lang) then
      table.insert(filtered, lang)
    end
  end
  if #filtered == 0 then
    util.notify("All parsers are up to date.")
    if callback then
      callback(true)
    end
    return
  end
  M.install_many(filtered, { force = true }, callback)
end

function M.uninstall(lang)
  if not registry.has(lang) then
    util.notify(("Unknown parser: %s"):format(lang), vim.log.levels.ERROR)
    return false
  end
  state.clear(lang)
  pcall(vim._ts_remove_language, lang)
  util.notify(("Uninstalled parser %s"):format(lang))
  return true
end

function M.ensure_installed(langs)
  local missing = {}
  for _, lang in ipairs(normalize_langs(langs)) do
    if registry.has(lang) and not state.is_installed(lang) then
      table.insert(missing, lang)
    end
  end
  if #missing > 0 then
    M.install_many(missing, {})
  end
end

return M
