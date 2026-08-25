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

Whenever the cursor is inside a table, editing keymaps are active (buffer-local, normal + insert mode):

| Key       | Action                      |
|-----------|-----------------------------|
| `<Tab>`   | next cell (past the last cell adds a row) |
| `<S-Tab>` | previous cell               |
| `<A-h/j/k/l>` | move to cell left/down/up/right |
| `<A-o>` / `<A-O>` | add row below / above |
| `<A-c>` / `<A-C>` | add column right / left |
| `<A-d>` / `<A-D>` | delete row / column |

Just type into a cell; on `InsertLeave` (or any normal-mode change) the table is re-rendered and the cursor stays in the same cell. Don't press `<CR>` inside a cell — use `<A-o>` for a new row. To make the first row a header, `<A-O>` on row 1.

`:BoxTableMode` toggles the keymaps manually (use with `auto_mode = false`).

## Options

```lua
require("boxtable").setup({
  width = 90,       -- target total table width; the widest columns wrap to fit
  pad = 1,          -- spaces on each side of cell contents
  auto_mode = true, -- enable keymaps when the cursor is inside a table
  keymaps = {       -- set any to "" to disable
    next_cell = "<Tab>", prev_cell = "<S-Tab>",
    cell_left = "<A-h>", cell_down = "<A-j>", cell_up = "<A-k>", cell_right = "<A-l>",
    row_below = "<A-o>", row_above = "<A-O>",
    col_right = "<A-c>", col_left = "<A-C>",
    delete_row = "<A-d>", delete_col = "<A-D>",
  },
})
```

All actions are also exposed as functions (`require("boxtable").row_below()` etc.) for custom mappings.
