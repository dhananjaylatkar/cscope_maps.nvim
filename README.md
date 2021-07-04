# cscope_maps.nvim
For old school code navigation :). 

Only supports [neovim](https://neovim.io/). Heavily inspired by emacs' [xcscope.el](https://github.com/dkogan/xcscope.el).

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

require('cscope_maps') -- initialize cscope maps
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

