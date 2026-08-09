return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
  },
  config = function()
    require("nvim-tree").setup({
      view = { width = 32 },
      renderer = {
        group_empty = true,
        highlight_git = true,
        icons = {
          show = { git = true },
        },
      },
      git = {
        enable = true,
        ignore = false, -- still show .gitignore'd files, but marked
      },
      filters = { dotfiles = false },
    })
  end,
}
