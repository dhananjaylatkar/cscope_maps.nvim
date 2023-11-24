# cscope_maps.nvim

For old school code navigation :)

Heavily inspired by emacs' [xcscope.el](https://github.com/dkogan/xcscope.el).

**Adds `cscope` support for [Neovim](https://neovim.io/) 0.9+**

[cscope_maps.nvim.webm](https://github.com/dhananjaylatkar/cscope_maps.nvim/assets/27724944/8b6a392a-c1d3-4ead-ae9b-a50436d52eef)

## 🌟 Cscope support

- Tries to mimic vim's builtin cscope functionality.
- Provides user command, `:Cscope` which acts same as good old `:cscope`.
- No need to add cscope database (`:cscope add <file>`), it is automaticaly picked from current directory or `db_file` option.
- Only want to use Cscope? No worries, keymaps can be disabled using `disable_maps` option.
- Supports `cscope` and `gtags-cscope`. Use `cscope.exec` option to specify executable.
- `:Cstag <symbol>` does `tags` search if no results are found in `cscope`.
- `:Cscope build` builds cscope db (no more going to terminal just to update the db)
  - `vim.g.cscope_maps_statusline_indicator` can be used in statusline to indicate ongoing db build.

## Features

- Opens results in quickfix, **telescope**, or **fzf-lua**.
- Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints.
- See [this section](#vim-gutentags) for `vim-gutentags`.

## Installation

Install the plugin with your preferred package manager.
Following example uses [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "dhananjaylatkar/cscope_maps.nvim",
  dependencies = {
    "folke/which-key.nvim", -- optional [for whichkey hints]
    "nvim-telescope/telescope.nvim", -- optional [for picker="telescope"]
    "ibhagwan/fzf-lua", -- optional [for picker="fzf-lua"]
    "nvim-tree/nvim-web-devicons", -- optional [for devicons in telescope or fzf]
  },
  opts = {
    -- USE EMPTY FOR DEFAULT OPTIONS
    -- DEFAULTS ARE LISTED BELOW
  },
}
```

## Configuration

_cscope_maps_ comes with following defaults:

```lua
{
  -- maps related defaults
  disable_maps = false, -- "true" disables default keymaps
  skip_input_prompt = false, -- "true" doesn't ask for input
  prefix = "<leader>c", -- prefix to trigger maps

  -- cscope related defaults
  cscope = {
    -- location of cscope db file
    db_file = "./cscope.out",
    -- cscope executable
    exec = "cscope", -- "cscope" or "gtags-cscope"
    -- choose your fav picker
    picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
    -- size of quickfix window
    qf_window_size = 5, -- any positive integer
    -- position of quickfix window
    qf_window_pos = "bottom", -- "bottom", "right", "left" or "top"
    -- "true" does not open picker for single result, just JUMP
    skip_picker_for_single_result = false, -- "false" or "true"
    -- these args are directly passed to "cscope -f <db_file> <args>"
    db_build_cmd_args = { "-bqkv" },
    -- statusline indicator, default is cscope executable
    statusline_indicator = nil,
  }
}
```

## vim-gutentags

### Config for vim-gutentags

```lua
{
  "ludovicchabant/vim-gutentags",
  init = function()
    vim.g.gutentags_modules = {"cscope_maps"} -- This is required. Other config is optional
    vim.g.gutentags_cscope_build_inverted_index_maps = 1
    vim.g.gutentags_cache_dir = vim.fn.expand("~/code/.gutentags")
    vim.g.gutentags_file_list_command = "fd -e c -e h"
    -- vim.g.gutentags_trace = 1
  end,
}
```

## Keymaps

### Default Keymaps

`<prefix>` can be configured using `prefix` option. Default value for prefix
is `<leader>c`.

(Try setting it to `C-c` 😉)

| Keymaps           | Description                                         |
| ----------------- | --------------------------------------------------- |
| `<prefix>s`       | find all references to the token under cursor       |
| `<prefix>g`       | find global definition(s) of the token under cursor |
| `<prefix>c`       | find all calls to the function name under cursor    |
| `<prefix>t`       | find all instances of the text under cursor         |
| `<prefix>e`       | egrep search for the word under cursor              |
| `<prefix>f`       | open the filename under cursor                      |
| `<prefix>i`       | find files that include the filename under cursor   |
| `<prefix>d`       | find functions that function under cursor calls     |
| `<prefix>a`       | find places where this symbol is assigned a value   |
| `<prefix>b`       | build cscope database                               |
| <kbd>Ctrl-]</kbd> | do `:Cstag <cword>`                                 |

### Custom Keymaps

Disable default keymaps by setting `disable_maps = true`.

There are 2 ways to add keymaps for `Cscope`.

#### Using `cscope_prompt()` function

`cscope_prompt(operation, default_symbol)` is exposed to user.
This function provides prompt which asks for input (see screenshots below)
before running `:Cscope` command.

e.g. Following snippet maps <kbd>C-c C-g</kbd> to find global def of symbol
under cursor

```lua
vim.keymap.set(
  "n",
  "<C-c><C-g>",
  [[<cmd>lua require('cscope_maps').cscope_prompt('g', vim.fn.expand("<cword>"))<cr>]],
  { noremap = true, silent = true }
)
```

#### Using `:Cscope` command

Use `vim.api.nvim_set_keymap()` to set keymap for cscope.

e.g. Following snippet maps <kbd>C-c C-g</kbd> to find global def of symbol
under cursor

```lua
vim.keymap.set(
  "n",
  "<C-c><C-g>",
  [[<cmd>exe "Cscope find g" expand("<cword>")<cr>]],
  { noremap = true, silent = true }
)
```
