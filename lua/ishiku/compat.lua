local M = {}

function M.has(minor)
  return vim.version().major == 0 and vim.version().minor >= minor
end

function M.is_0_11()
  local version = vim.version()
  return version.major == 0 and version.minor == 11
end

function M.is_0_12_or_newer()
  local version = vim.version()
  return version.major > 0 or version.minor >= 12
end

return M
