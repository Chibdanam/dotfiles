require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<Tab>",
    accept_word = "<S-Tab>",
    clear_suggestion = "<C-]>",
  },
  -- Inline ghost-text suggestions; blink.cmp keeps handling the popup menu.
  disable_inline_completion = false,
  disable_keymaps = false,
})
