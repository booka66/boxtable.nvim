# boxtable.nvim

Turn pipe- or tab-delimited rows into Unicode box-drawing tables, with word-wrapped cells and a centered header row.

```
| | In pipeline.ts | Before SQS enqueue |
| Pro | one controlled place, already has the customer doc + claim logic | doesn't block event processing for everyone |
```

`:'<,'>BoxTable` →

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
{ "booka66/boxtable.nvim", cmd = "BoxTable", opts = {} }
```

## Usage

- `:'<,'>BoxTable` — convert the selected lines. Input can be `| a | b |`, `a | b`, tab-separated, or an existing box table (re-run to reflow after editing).
- `:'<,'>BoxTable 40` — override max column width for this call.
- Markdown `|---|---|` separator rows are ignored. First row is the header (centered).

Suggested mapping:

```lua
vim.keymap.set("v", "<leader>tb", ":BoxTable<CR>")
```

## Options

```lua
require("boxtable").setup({
  max_width = 90, -- wrap cell contents beyond this display width
  pad = 1,        -- spaces on each side of cell contents
})
```
