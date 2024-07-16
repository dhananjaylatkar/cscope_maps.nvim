# cscope_maps.nvim

For old school code navigation :)

Heavily inspired by emacs' [xcscope.el](https://github.com/dkogan/xcscope.el).

**Adds `cscope` support for [Neovim](https://neovim.io/) 0.9+**

[cscope_maps.nvim.v2.webm](https://github.com/dhananjaylatkar/cscope_maps.nvim/assets/27724944/7ab4d902-fe6d-4914-bff6-353136c72803)

## Features

### Cscope

- Tries to mimic vim's builtin cscope functionality.
- Provides user command, `:Cscope` which acts same as good old `:cscope`.
- Short commands are supported. e.g. `:Cs f g main`
- Keymaps can be disabled using `disable_maps` option.
- Supports `cscope` and `gtags-cscope`. Use `cscope.exec` option to specify executable.
- `:Cstag <symbol>` does `tags` search if no results are found in `cscope`.
- For `nvim < 0.9`, legacy cscope will be used. It will support keymaps. It won't have all the niceties of lua port.
- Display results in quickfix, **telescope**, **fzf-lua** or **mini.pick**.
- Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints.
- See [this section](#vim-gutentags) for `vim-gutentags`.

### Cscope DB

- Statically provide table of db paths in config (`db_file`) OR add them at runtime using `:Cs db add ...`
- `:Cs db add <space sepatated files>` add db file(s) to cscope search.
- `:Cs db rm <space sepatated files>` remove db file(s) from cscope search.
- `:Cs db show` show all db connections.
- `:Cs db build` (re)builds db for primary db.
- `vim.g.cscope_maps_statusline_indicator` can be used in statusline to indicate ongoing db build.
- DB path grammar
  - `db_file:db_pre_path` db_pre_path (prefix path) will be appended to cscope results.
  - e.g. `:Cs db add ~/cscope.out:/home/code/proj2` => results from `~/cscope.out` will be prefixed with `/home/code/proj2/`
  - `@` can be used to indicate that parent of `db_file` is `db_pre_path`.
  - e.g. `:Cs db add ../proj2/cscope.out:@` => results from `../proj2/cscope.out` will be prefixed with `../proj2/`

### Stack View

- Visualize tree of caller functions and called functions.
- `:CsStackView open down <sym>` Opens "downward" stack showing all the functions who call the `<sym>`.
- `:CsStackView open up <sym>` Opens "upward" stack showing all the functions called by the `<sym>`.
- In `CsStackView` window, use following keymaps
  - `<tab>` toggle child under cursor
  - `<cr>` open location of symbol under cursor
  - `q` close window
- `:CsStackView toggle` reopens last `CsStackView` window.
- In `CsStackView` window, all nodes that are part of current stack are highlighted.

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
    "echasnovski/mini.pick" -- optional [for picker="mini-pick"]
    "nvim-tree/nvim-web-devicons", -- optional [for devicons in telescope, fzf or mini.pick]
  },
  opts = {
    -- USE EMPTY FOR DEFAULT OPTIONS
    -- DEFAULTS ARE LISTED BELOW
  },
}
```

## Configuration

You must run `require("cscope_maps").setup()` to initialize the plugin even when using default options.

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
    db_file = "./cscope.out", -- DB or table of DBs
                              -- NOTE:
                              --   when table of DBs is provided -
                              --   first DB is "primary" and others are "secondary"
                              --   primary DB is used for build and project_rooter
    -- cscope executable
    exec = "cscope", -- "cscope" or "gtags-cscope"
    -- choose your fav picker
    picker = "quickfix", -- "quickfix", "telescope", "fzf-lua" or "mini-pick"
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
    -- try to locate db_file in parent dir(s)
    project_rooter = {
      enable = false, -- "true" or "false"
      -- change cwd to where db_file is located
      change_cwd = false, -- "true" or "false"
    },
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

### Alternative to vim-gutentags

Alternative to gutentags is to rebuild DB using `:Cscope db build` or `<prefix>b`.

You can create autocmd for running `:Cscope db build` after saving .c and .h files.
e.g

```lua
local group = vim.api.nvim_create_augroup("CscopeBuild", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.c", "*.h" },
  callback = function ()
    vim.cmd("Cscope db build")
  end,
  group = group,
})
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
