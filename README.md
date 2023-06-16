# cscope_maps.nvim
For old school code navigation :)

Only supports [neovim](https://neovim.io/). Heavily inspired by emacs' [xcscope.el](https://github.com/dkogan/xcscope.el).

**Now with `cscope` support for Neovim 0.9+**


* [🌟 Cscope support](#-cscope-support)
* [Features](#features)
* [Installaion](#installaion)
  * [packer](#packer)
  * [vim-plug](#vim-plug)
* [vim-gutentags](#vim-gutentags)
  * [Config for vim-gutentags](#config-for-vim-gutentags)
* [Keymaps](#keymaps)
  * [Default Keymaps](#default-keymaps)
  * [Custom Keymaps](#custom-keymaps)
    * [Using `cscope_prompt()` function](#using-cscope_prompt-function)
    * [Using `:Cscope` command](#using-cscope-command)
* [Sreenshots](#sreenshots)
  * [Asks for input when invoked](#asks-for-input-when-invoked-default-input-is-wordfile-under-cursor)
  * [Opens results in Quickfix window](#opens-results-in-quickfix-window)
  * [Results in telescope picker](#results-in-telescope-picker)
  * [which-key hints](#which-key-hints)

## 🌟 Cscope support
- Tries to mimic vim's builtin cscope functionality.
- Provides user command, `:Cscope` which acts same as good old `:cscope`.
- No need to add cscope database (`:cscope add <file>`), it is automaticaly picked from current directory or `db_file` option.
- Only want to use Cscope? No worries, keymaps can be disabled using `disable_maps` option.
- Supports `cscope` and `gtags-cscope`. Use `cscope.exec` option to specify executable.
- `:Cstag <symbol>` does `tags` search if no results are found in `cscope`.

## Features
* Opens results in quickfix, **telescope**, or **fzf-lua**.
* Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints baked in.
* See [this](https://github.com/dhananjaylatkar/cscope_maps.nvim/edit/main/README.md#vim-gutentags) for `vim-gutentags`.

## Installaion
Install the plugin with your preferred package manager.

### [packer](https://github.com/wbthomason/packer.nvim)
``` lua
-- Lua
use 'dhananjaylatkar/cscope_maps.nvim' -- cscope keymaps
use 'folke/which-key.nvim' -- optional
use 'nvim-telescope/telescope.nvim' -- required for picker = "telescope"
use 'ibhagwan/fzf-lua' -- required for picker = "fzf-lua"

-- load cscope maps
-- pass empty table to setup({}) for default options
require('cscope_maps').setup({
  disable_maps = false, -- true disables my keymaps, only :Cscope will be loaded
  cscope = {
    db_file = "./cscope.out", -- location of cscope db file
    exec = "cscope", -- "cscope" or "gtags-cscope"
    picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
    skip_picker_for_single_result = false, -- jump directly to position for single result
    db_build_cmd_args = { "-bqkv" }, -- args used for db build (:Cscope build)
  },
})
```

### [vim-plug](https://github.com/junegunn/vim-plug)
```vim
" Vim Script
Plug 'dhananjaylatkar/cscope_maps.nvim' " cscope keymaps
Plug 'folke/which-key.nvim' " optional
Plug 'nvim-telescope/telescope.nvim' " required for picker = 'telescope'
Plug 'ibhagwan/fzf-lua' " required for picker = 'fzf-lua'

lua << EOF
  require("cscope_maps").setup({})
EOF
```

## vim-gutentags

Cscope provided by this plugin is not exactly same as built-in vim cscope, vim-gutentags fails to load.

I have created a [patch](https://github.com/ludovicchabant/vim-gutentags/pull/346) to support this plugin and my fork can be used until it's merged in upstream.

### Config for vim-gutentags
```lua
use({
  "dhananjaylatkar/vim-gutentags",
  after = "cscope_maps.nvim",
  config = function()
    vim.g.gutentags_modules = {"cscope_maps"} -- This is required. Other config is optional
    vim.g.gutentags_cscope_build_inverted_index_maps = 1
    vim.g.gutentags_cache_dir = vim.fn.expand("~/code/.gutentags")
    vim.g.gutentags_file_list_command = "fd -e c -e h"
    -- vim.g.gutentags_trace = 1
  end,
})
```

## Keymaps

### Default Keymaps

| Keymaps               | Description                                         |
|-----------------------|-----------------------------------------------------|
| <kbd><leader>cs</kbd> | find all references to the token under cursor       |
| <kbd><leader>cg</kbd> | find global definition(s) of the token under cursor |
| <kbd><leader>cc</kbd> | find all calls to the function name under cursor    |
| <kbd><leader>ct</kbd> | find all instances of the text under cursor         |
| <kbd><leader>ce</kbd> | egrep search for the word under cursor              |
| <kbd><leader>cf</kbd> | open the filename under cursor                      |
| <kbd><leader>ci</kbd> | find files that include the filename under cursor   |
| <kbd><leader>cd</kbd> | find functions that function under cursor calls     |
| <kbd><leader>ca</kbd> | find places where this symbol is assigned a value   |
| <kbd><leader>cb</kbd> | build cscope database                               |
| <kbd>Ctrl-]</kbd>     | do `:Cstag <cword>`                                 |

### Custom Keymaps

Disable default keymaps by setting `disable_maps = true`.

There are 2 ways to add keymaps for `Cscope`.

#### Using `cscope_prompt()` function

`cscope_prompt(operation, default_symbol)` is exposed to user. This function provides prompt which asks for input (see screenshots below) before running `:Cscope` command.

e.g. Following snippet maps <kbd>C-c C-g</kbd> to find global def of symbol under cursor
```lua
vim.api.nvim_set_keymap(
  "n",
  "<C-c><C-g>",
  [[<cmd>lua require('cscope_maps').cscope_prompt('g', vim.fn.expand("<cword>"))<cr>]],
  { noremap = true, silent = true }
) 
```

#### Using `:Cscope` command

Use `vim.api.nvim_set_keymap()` to set keymap for cscope.

e.g. Following snippet maps <kbd>C-c C-g</kbd> to find global def of symbol under cursor
```lua
vim.api.nvim_set_keymap(
  "n",
  "<C-c><C-g>",
  [[<cmd>exe "Cscope find g" expand("<cword>"))<cr>]],
  { noremap = true, silent = true }
) 
```

## Sreenshots

### Asks for input when invoked. (Default input is word/file under cursor)

![Input](./pics/2-input-prompt.png "Input")

### Opens results in Quickfix window

![Quickfix](./pics/3-qf-window.png "Quickfix window")

### Results in telescope picker
![cscope telescope](./pics/5-cs-telescope.png "cscope telescope")

### [which-key](https://github.com/folke/which-key.nvim) hints

![which-key Hints](./pics/4-wk-hints.png "which-key pane")
