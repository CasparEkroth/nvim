return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { "<C-t>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal", mode = { "n", "t" } },
  },
  opts = {
    direction = "float", -- or "horizontal" / "vertical"
    size = 15,
  },
}
