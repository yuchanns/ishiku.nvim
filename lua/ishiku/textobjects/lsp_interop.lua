local shared = require('ishiku.textobjects.shared')
local config = require('ishiku.textobjects.config')

local M = {}

local function get_definition_location(result)
  if not result then
    return nil
  end
  if vim.islist(result) then
    local item = result[1]
    if not item then
      return nil
    end
    return item.targetUri and {
      uri = item.targetUri,
      range = item.targetSelectionRange or item.targetRange,
    } or item
  end
  if result.targetUri then
    return {
      uri = result.targetUri,
      range = result.targetSelectionRange or result.targetRange,
    }
  end
  return result
end

local function make_params_from_range(range)
  local client = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/definition' })[1]
  local encoding = client and client.offset_encoding or 'utf-8'
  local params = vim.lsp.util.make_position_params(0, encoding)
  params.position = {
    line = range[1],
    character = range[2],
  }
  return params
end

function M.peek_definition_code(query_string, query_group)
  query_group = query_group or 'textobjects'
  local bufnr = vim.api.nvim_get_current_buf()
  local range = shared.textobject_at_point(query_string, query_group, bufnr)
  if not range then
    return
  end

  local params = make_params_from_range(range)
  local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/definition', params, 1000)
  if not responses then
    return
  end

  for _, response in pairs(responses) do
    if response and response.result then
      local location = get_definition_location(response.result)
      if location then
        return vim.lsp.util.preview_location(location, config.lsp_interop.floating_preview_opts)
      end
    end
  end
end

return M
