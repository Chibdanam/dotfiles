require("note_helper").setup({})

-- Normal mode: operate on the whole buffer.
vim.keymap.set("n", "<leader>nf", "<cmd>Note format<cr>", { desc = "Note: format" })
vim.keymap.set("n", "<leader>nt", "<cmd>Note typos<cr>", { desc = "Note: fix typos" })
vim.keymap.set("n", "<leader>ns", "<cmd>Note summarize<cr>", { desc = "Note: summarize" })
vim.keymap.set("n", "<leader>nd", "<cmd>Note todos<cr>", { desc = "Note: extract TODOs" })
-- Visual mode: ':' auto-inserts the selection range so only it is processed.
vim.keymap.set("x", "<leader>nf", ":Note format<cr>", { desc = "Note: format selection" })
vim.keymap.set("x", "<leader>nt", ":Note typos<cr>", { desc = "Note: fix typos in selection" })
