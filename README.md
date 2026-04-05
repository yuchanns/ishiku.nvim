# ishiku.nvim

Neovim 0.12+ Treesitter parser manager.

Install `ishiku.nvim` together with `ishiku-registry`.

This repository is entirely AI-generated.

## Setup

```lua
require("ishiku").setup({
  ensure_installed = { "lua", "vim", "python" },
  auto_install = true,
  sync_install = false,
  registries = { "github:yuchanns/ishiku-registry" },
})
```

## Commands

- `:Ishiku`
- `:IshikuInstall <parser> ...`
- `:IshikuUpdate [parser] ...`
- `:IshikuUninstall <parser> ...`
- `:IshikuInfo`
- `:IshikuLog`
- `:IshikuRegistryUpdate`

## Requirements

- Neovim 0.12+
- `git`
- one of: `cc`, `gcc`, `clang`, `cl`, `zig`
- `tree-sitter` and `node` for parsers that must be generated from grammar
- `npm` for parsers with generation-time npm dependencies

## Usage

```vim
:IshikuInstall lua
:IshikuInstall go
:IshikuUpdate
:Ishiku
:checkhealth ishiku
```
