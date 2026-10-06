-- LSP server setup + attach keymaps

local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Python: type checking, hover, go-to-def, autocomplete
vim.lsp.config["basedpyright"] = {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
  capabilities = capabilities,
}
vim.lsp.enable("basedpyright")

-- Python: fast linting + formatting
vim.lsp.config["ruff"] = {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".git" },
  capabilities = capabilities,
}
vim.lsp.enable("ruff")

-- C/C++: clangd (completion, go-to-def, diagnostics, formatting)
local clangd_capabilities = vim.deepcopy(capabilities)
clangd_capabilities.offsetEncoding = { "utf-16" }

vim.lsp.config["clangd"] = {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders=true",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = {
    "compile_commands.json",
    "compile_flags.txt",
    ".clangd",
    "CMakeLists.txt",
    "Makefile",
    ".git",
  },
  capabilities = clangd_capabilities,
}
vim.lsp.enable("clangd")

-- Lua: for editing this config itself
vim.lsp.config["lua_ls"] = {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".git" },
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
    },
  },
}
vim.lsp.enable("lua_ls")

-- Robot Framework: completion, go-to-def, diagnostics for .robot/.resource files
vim.lsp.config["robotcode"] = {
  cmd = { "robotcode", "language-server" },
  filetypes = { "robot", "resource" },
  root_markers = { "robot.toml", "pyproject.toml", "Pipfile", ".git" },
  capabilities = capabilities,
}
vim.lsp.enable("robotcode")

-- Docker: completion, hover, diagnostics for Dockerfiles
vim.lsp.config["dockerls"] = {
  cmd = { "docker-langserver", "--stdio" },
  filetypes = { "dockerfile" },
  root_markers = { "Dockerfile", ".git" },
  capabilities = capabilities,
}
vim.lsp.enable("dockerls")

-- Docker Compose: completion, hover, diagnostics for compose files
vim.lsp.config["docker_compose_language_service"] = {
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml", ".git" },
  capabilities = capabilities,
}
vim.lsp.enable("docker_compose_language_service")

-- Keymaps when an LSP attaches to a buffer
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "K", function()
      vim.lsp.buf.hover({ border = "rounded" })
    end, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>e2", vim.diagnostic.open_float, opts)
    vim.keymap.set("i", "<C-s>", function()
      vim.lsp.buf.signature_help({ border = "rounded" })
    end, opts)
    vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })

    vim.keymap.set("n", "<leader>ih", function()
      vim.lsp.inlay_hint.enable(
        not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }),
        { bufnr = ev.buf }
      )
    end, vim.tbl_extend("force", opts, { desc = "Toggle inlay hints" }))
  end,
})
