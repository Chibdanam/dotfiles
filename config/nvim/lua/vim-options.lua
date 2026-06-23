vim.g.mapleader = " "

-- Neovim core doesn't map .razor to filetype `razor`; needed for roslyn_ls to attach.
vim.filetype.add({ extension = { razor = "razor" } })

local opt = vim.opt

if not vim.env.SSH_CONNECTION and vim.fn.has("clipboard") == 1 then
  opt.clipboard = "unnamedplus"
end

opt.completeopt = "menu,menuone,noselect"
opt.confirm = true -- Confirm to save changes before exiting modified buffer
opt.cursorline = true -- Enable highlighting of the current line
opt.expandtab = true -- Use spaces instead of tabs
opt.fillchars = { eob = " " } -- Hide ~ on lines past end of buffer
opt.laststatus = 0 -- Statusline hidden by default; toggled with <leader>o
opt.list = true -- Show some invisible characters (tabs...
opt.mouse = "a" -- Enable mouse mode
opt.number = true -- Print line number
opt.relativenumber = true -- Relative line numbers
opt.shiftwidth = 2 -- Size of an indent
opt.showmode = false -- Dont show mode since we have a statusline
opt.smartcase = true -- Don't ignore case with capitals
opt.smartindent = true -- Insert indents automatically
opt.splitbelow = true -- Put new windows below current
opt.splitright = true -- Put new windows right of current
opt.tabstop = 2 -- Number of spaces tabs count for
opt.softtabstop = 2
opt.undofile = true
opt.undolevels = 10000
opt.wrap = true
opt.scrolloff = 999 -- Lines of context
opt.sidescrolloff = 8 -- Columns of context

-- Inherit the terminal emulator's background instead of the default
-- colorscheme's `Normal ctermbg=Black`. Re-applied on every ColorScheme
-- event so it survives plugin-driven scheme changes.
local function clear_normal_bg()
  vim.api.nvim_set_hl(0, "Normal", { ctermbg = "NONE", ctermfg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalNC", { ctermbg = "NONE", ctermfg = "NONE" })
  vim.api.nvim_set_hl(0, "EndOfBuffer", { ctermbg = "NONE", ctermfg = "NONE" })
end
clear_normal_bg()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("inherit-terminal-bg", { clear = true }),
  callback = clear_normal_bg,
})

-- Replace LSP diagnostic sign letters (E/W/H/I) with a thin vertical bar
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "▎",
      [vim.diagnostic.severity.WARN] = "▎",
      [vim.diagnostic.severity.HINT] = "▎",
      [vim.diagnostic.severity.INFO] = "▎",
    },
  },
})

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "close buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "next buffer" })
vim.keymap.set("n", "<leader>o", function()
  vim.opt.laststatus = vim.o.laststatus == 0 and 3 or 0
end, { desc = "toggle statusline" })
