# ishiku.nvim

Neovim 0.11 and 0.12 Treesitter parser manager and runtime integration for `vim.treesitter`.

`ishiku.nvim` manages parser installation, activates registry-provided runtime files,
auto-starts Treesitter for supported buffers, and provides a `textobjects` module
compatible with the common `nvim-treesitter` workflow.

Use it together with `ishiku-registry`.

This repository is entirely AI-generated.

## Features

- Install and update Treesitter parsers.
- Activate registry runtime assets such as `queries/*/*.scm`.
- Auto-start `vim.treesitter` for file-backed buffers.
- Provide `textobjects` support on top of `vim.treesitter`:
  - `select`
  - `move`
  - `swap`
  - `repeatable_move`
  - `incremental_selection`
  - `lsp_interop`

## Setup

```lua
require("ishiku").setup {
  ensure_installed = { "lua", "vim", "python" },
  auto_install = true,
  sync_install = false,
  registries = { "github:yuchanns/ishiku-registry" },
}
```

## Textobjects

`ishiku.nvim` can expose a `textobjects` configuration model close to
`nvim-treesitter-textobjects`.

```lua
require("ishiku").setup {
  ensure_installed = { "lua", "vim", "go", "rust", "python", "typescript" },
  auto_install = true,
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      },
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>a"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader>A"] = "@parameter.inner",
      },
    },
    lsp_interop = {
      enable = true,
      peek_definition_code = {
        ["<leader>pf"] = "@function.outer",
        ["<leader>pc"] = "@class.outer",
      },
    },
    repeatable_move = {
      enable = true,
      repeat_last_move_next = ";",
      repeat_last_move_previous = ",",
      builtin_f = "f",
      builtin_F = "F",
      builtin_t = "t",
      builtin_T = "T",
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = ".",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
  },
}
```

The query data for textobjects lives in `ishiku-registry` under
`queries/<lang>/textobjects.scm`.

## Commands

- `:Ishiku`
- `:IshikuInstall <parser> ...`
- `:IshikuUpdate [parser] ...`
- `:IshikuUninstall <parser> ...`
- `:IshikuInfo`
- `:IshikuLog`
- `:IshikuRegistryUpdate`

## Requirements

- Neovim 0.11 or 0.12
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

## Migration Notes

When migrating from `nvim-treesitter` to `vim.treesitter`:

- `ishiku.nvim` manages parser installation.
- `ishiku-registry` provides runtime queries for external languages.
- `ishiku.nvim` auto-starts Treesitter and can restore common textobject flows.
- Builtin Neovim languages may already ship parsers and queries; registry data
  extends the runtime for languages Neovim does not bundle.
