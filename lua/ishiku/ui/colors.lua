local hl_groups = {
  IshikuBackdrop = { bg = "#000000", default = true },
  IshikuNormal = { link = "NormalFloat", default = true },
  IshikuHeader = { bold = true, fg = "#222222", bg = "#DCA561", default = true },
  IshikuHeaderSecondary = { bold = true, fg = "#222222", bg = "#56B6C2", default = true },
  IshikuHighlight = { fg = "#56B6C2", default = true },
  IshikuMuted = { fg = "#888888", default = true },
  IshikuError = { link = "ErrorMsg", default = true },
  IshikuWarning = { link = "WarningMsg", default = true },
  IshikuHeading = { bold = true, default = true },
  IshikuCursorLine = { link = "CursorLine", default = true },
}

for name, hl in pairs(hl_groups) do
  vim.api.nvim_set_hl(0, name, hl)
end
