return {
  { "williamboman/mason.nvim", config = true },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "basedpyright", "ruff", "lua_ls", "clangd" },
    },
  },
  { "neovim/nvim-lspconfig" },
}
