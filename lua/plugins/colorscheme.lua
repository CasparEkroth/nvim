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
      custom_highlights = function(colors)
        -- Editor stays pure black; LSP/diagnostic floats use a soft light
        -- surface. Which-key (<leader>f hints, etc.) is pinned back to the
        -- dark palette so it is not affected by NormalFloat.
        local editor_bg = "#000000"
        local float_bg = "#EFF1F5" -- catppuccin latte base
        local float_fg = "#4C4F69" -- catppuccin latte text
        local float_border = colors.blue
        return {
          Normal = { bg = editor_bg },
          NormalFloat = { bg = float_bg, fg = float_fg },
          FloatBorder = { bg = float_bg, fg = float_border },
          FloatTitle = { bg = float_bg, fg = colors.mauve, bold = true },
          -- Keep which-key on the dark theme (do not follow NormalFloat)
          WhichKeyNormal = { bg = editor_bg, fg = colors.text },
          WhichKeyBorder = { bg = editor_bg, fg = colors.blue },
          WhichKeyTitle = { bg = editor_bg, fg = colors.mauve, bold = true },
          NvimTreeNormal = { bg = editor_bg },
          TelescopeNormal = { bg = editor_bg },
        }
      end,
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
