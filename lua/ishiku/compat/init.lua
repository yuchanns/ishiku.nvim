local M = {}

function M.version()
  return vim.version()
end

function M.has(minor)
  local version = M.version()
  return version.major == 0 and version.minor >= minor
end

function M.is_0_11()
  local version = M.version()
  return version.major == 0 and version.minor == 11
end

function M.is_0_12_or_newer()
  local version = M.version()
  return version.major > 0 or version.minor >= 12
end

function M.version_keys()
  local version = M.version()
  return {
    ("nvim-%d.%d.%d"):format(version.major, version.minor, version.patch),
    ("nvim-%d.%d"):format(version.major, version.minor),
    ("nvim-%d"):format(version.major),
    "default",
  }
end

return M
