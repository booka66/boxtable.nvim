# boxtable.nvim

Unicode box-drawing tables you can edit in place. Convert pipe/tab rows into a table, then move between cells, add/remove rows and columns, and type into cells — the table re-renders (with word-wrapped cells and a centered header row) whenever you leave insert mode.

```
┌─────┬────────────────────────────────────┬─────────────────────────────────────────────┐
│     │           In pipeline.ts           │             Before SQS enqueue              │
├─────┼────────────────────────────────────┼─────────────────────────────────────────────┤
│ Pro │ one controlled place, already has  │ doesn't block event processing for everyone │
│     │ the customer doc + claim logic     │                                             │
└─────┴────────────────────────────────────┴─────────────────────────────────────────────┘
```

## Install

lazy.nvim:

```lua
{ "booka66/boxtable.nvim", opts = {} }
```

## Usage

- `:BoxTable` — insert an empty 2×2 table at the cursor.
- `:'<,'>BoxTable` — convert selected lines. Accepts `| a | b |`, `a | b`, tab-separated, or an existing box table (reflows it). Markdown `|---|` rows are ignored. First row is the header.
- `:'<,'>BoxTable 60` — override the total table width for this call.

Whenever the cursor is inside a table, editing keymaps are active (buffer-local):

| Key       | Action                      |
|-----------|-----------------------------|
| `<Tab>`   | next cell, cursor at end of its text (past the last cell adds a row) — normal + insert; from insert mode you stay in insert |
| `<S-Tab>` | previous cell — normal + insert |
| `<leader>th/j/k/l` | move to cell left/down/up/right |
| `<leader>to` / `<leader>tO` | add row below / above |
| `<leader>tc` / `<leader>tC` | add column right / left |
| `<leader>td` / `<leader>tD` | delete row / column |

Just type into a cell; on `InsertLeave` (or any normal-mode change) the table is re-rendered and the cursor stays in the same cell. Don't press `<CR>` inside a cell — use `<leader>to` for a new row. To make the first row a header, `<leader>tO` on row 1.

`:BoxTableMode` toggles the keymaps manually (use with `auto_mode = false`).

## Options

```lua
require("boxtable").setup({
  width = 90,       -- target total table width; the widest columns wrap to fit
  pad = 1,          -- spaces on each side of cell contents
  auto_mode = true, -- enable keymaps when the cursor is inside a table
  keymaps = {       -- set any to "" to disable
    next_cell = "<Tab>", prev_cell = "<S-Tab>",
    cell_left = "<leader>th", cell_down = "<leader>tj", cell_up = "<leader>tk", cell_right = "<leader>tl",
    row_below = "<leader>to", row_above = "<leader>tO",
    col_right = "<leader>tc", col_left = "<leader>tC",
    delete_row = "<leader>td", delete_col = "<leader>tD",
  },
})
```

All actions are also exposed as functions (`require("boxtable").row_below()` etc.) for custom mappings.
