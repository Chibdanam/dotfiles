require("which-key").setup({
  plugins = { spelling = true },
  spec = {
    {
      mode = { "n", "v" },
      { "<leader>b", group = "buffer" },
      { "<leader>f", group = "file/find" },
      { "<leader>s", group = "search" },
    },
  },
})
