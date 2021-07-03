# cscope_maps.nvim
For old school code navigation :)

cscope keymaps are loaded only if project contains `cscope.out`. This allows us to use same keymaps for other tasks.

It opens results in quickfix window so, it's easier to go through results.

# Installaion
Use your favourite package manager.

## Packer
``` lua
use 'dhananjaylatkar/cscope_maps.nvim' -- cscope keymaps

require('cscope_maps').setup()         -- initialize cscope maps
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

