-- Basic Neovim options

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Dedicated Python host for molten-nvim / remote plugins + jupytext CLI.
-- Created by ./setup at stdpath('data')/venv (Python >= 3.10).
do
  local data = vim.fn.stdpath("data")
  local venv_python = data .. "/venv/bin/python"
  local venv_python_win = data .. "/venv/Scripts/python.exe"
  local venv_bin = data .. "/venv/bin"
  local venv_bin_win = data .. "/venv/Scripts"
  if vim.uv.fs_stat(venv_python) then
    vim.g.python3_host_prog = venv_python
    vim.env.PATH = venv_bin .. ":" .. (vim.env.PATH or "")
  elseif vim.uv.fs_stat(venv_python_win) then
    vim.g.python3_host_prog = venv_python_win
    vim.env.PATH = venv_bin_win .. ";" .. (vim.env.PATH or "")
  end
end

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.updatetime = 250
vim.opt.pumheight = 15
vim.opt.scrolloff = 8
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.clipboard = "unnamedplus"
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.lsp.foldexpr()"
vim.opt.foldlevelstart = 99
vim.opt.spelllang = "en_us"
vim.opt.spell = true

-- Diagnostics appearance
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  float = { border = "rounded", source = true },
})
