return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      integrations = {
        cmp = true,
        treesitter = true,
        native_lsp = { enabled = true },
        gitsigns = true,
        nvimtree = true,
        which_key = true,
      },
      custom_highlights = function()
        return {
          Normal = { bg = "#000000" },
          NormalFloat = { bg = "#000000" },
          NvimTreeNormal = { bg = "#000000" },
          TelescopeNormal = { bg = "#000000" },
        }
      end,
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
