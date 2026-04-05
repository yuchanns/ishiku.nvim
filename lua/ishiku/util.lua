local M = {}

function M.is_windows()
  return vim.fn.has("win32") == 1
end

function M.is_macos()
  return vim.fn.has("mac") == 1
end

function M.joinpath(...)
  return vim.fs.joinpath(...)
end

function M.exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

function M.read_json(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end

function M.write_json(path, value)
  M.write_lines(path, vim.split(vim.json.encode(value), "\n", { plain = true }))
end

function M.write_lines(path, lines)
  vim.fn.writefile(lines, path)
end

function M.mkdirp(path)
  vim.fn.mkdir(path, "p")
end

function M.rmrf(path)
  vim.fn.delete(path, "rf")
end

function M.notify(message, level)
  vim.notify(("[ishiku] %s"):format(message), level or vim.log.levels.INFO)
end

function M.select_executable(candidates)
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= vim.NIL and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
end

function M.ensure_runtimepath(path)
  local rtp = vim.opt.runtimepath:get()
  if not vim.tbl_contains(rtp, path) then
    vim.opt.runtimepath:prepend(path)
  end
end

function M.system(cmd, opts, on_exit)
  opts = opts or {}
  opts.text = true
  return vim.system(cmd, opts, function(result)
    vim.schedule(function()
      on_exit(result)
    end)
  end)
end

function M.system_sync(cmd, opts)
  opts = opts or {}
  opts.text = true
  return vim.system(cmd, opts):wait()
end

function M.open(path)
  vim.cmd(("tabnew %s"):format(vim.fn.fnameescape(path)))
end

return M
