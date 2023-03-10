# cscope_maps.nvim
**Now with `cscope` support for Neovim 0.9+**

For old school code navigation :).

Only supports [neovim](https://neovim.io/). Heavily inspired by emacs' [xcscope.el](https://github.com/dkogan/xcscope.el).

# [NEW] Cscope support
- Tries to mimic vim's builtin cscope functionality.
- Provides user command, `:Cscope` which acts same as good old `:cscope`.
- No need to add cscope database (`:cscope add <file>`), it is automaticaly picked from current directory.
- Only want to use Cscope? No worries, disable keymaps using option.

# Features
* Opens results in quickfix window.
* Loads only if folder contains `cscope.out` file.
* Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints baked in. 

# Installaion
Install the plugin with your preferred package manager.

## [packer](https://github.com/wbthomason/packer.nvim)
``` lua
-- Lua
use 'dhananjaylatkar/cscope_maps.nvim' -- cscope keymaps
use 'folke/which-key.nvim' -- optional

-- load cscope maps
-- pass empty table to setup({}) for default options
require('cscope_maps').setup({
  disable_maps = false, -- true disables my keymaps, only :Cscope will be loaded
  cscope = {
    db_file = "./cscope.out", -- location of cscope db file
  },
})
```

### If you are lazy-loading which-key.nvim then, load cscope_maps.nvim after which-key.nvim
```lua
use({
  "dhananjaylatkar/cscope_maps.nvim",
  after = "which-key.nvim",
  config = function()
    require("cscope_maps").setup({})
  end,
})
```

## [vim-plug](https://github.com/junegunn/vim-plug)
```vim
" Vim Script
Plug 'dhananjaylatkar/cscope_maps.nvim' " cscope keymaps
Plug 'folke/which-key.nvim' " optional

lua << EOF
  require("cscope_maps")
EOF
```

# Keymaps

| Keymaps | Description |
|--- | --- |
|`<leader>cs`| find all references to the token under cursor |
|`<leader>cg`| find global definition(s) of the token under cursor |
|`<leader>cc`| find all calls to the function name under cursor |
|`<leader>ct`| find all instances of the text under cursor |
|`<leader>ce`| egrep search for the word under cursor |
|`<leader>cf`| open the filename under cursor |
|`<leader>ci`| find files that include the filename under cursor|
|`<leader>cd`| find functions that function under cursor calls |
|`<leader>ca`| find places where this symbol is assigned a value |

# Sreenshots
### Loads `cscope` DB if it's available.

![Load cscope](./pics/1-load-cscope.png "Load cscope")

### Asks for input when invoked. (Default takes word/file under cursor)

![Input](./pics/2-input-prompt.png "Input")

### Opens results in Quickfix window and selects first match.

![Quickfix](./pics/3-qf-window.png "Quickfix window")

### [which-key](https://github.com/folke/which-key.nvim) hints are baked in.

![which-key Hints](./pics/4-wk-hints.png "which-key pane")
