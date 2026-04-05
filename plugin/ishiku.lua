if vim.g.loaded_ishiku then
  return
end

vim.g.loaded_ishiku = 1

require("ishiku.command").register()
