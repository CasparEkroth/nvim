-- NOTE: on Neovim 0.12+ use the default/main branch (master is frozen
-- and only supports 0.10/0.11). The setup API changed in the rewrite.
return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      -- parsers install into stdpath('data')/site by default
    })

    -- Install parsers asynchronously (no-op if already present)
    -- markdown_inline is required by markdown injections / render-markdown.nvim
    require("nvim-treesitter").install({
      "python", "lua", "vim", "vimdoc",
      "json", "yaml", "toml",
      "markdown", "markdown_inline",
      "bash",
    })

    -- Highlighting is no longer a nvim-treesitter "module"; start it per buffer.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        -- pcall so missing parsers don't hard-error on every buffer
        pcall(vim.treesitter.start, ev.buf)
      end,
    })

    -- Optional: treesitter-based indentation (experimental on main)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "python", "lua", "vim", "json", "yaml", "toml", "markdown", "bash",
      },
      callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
