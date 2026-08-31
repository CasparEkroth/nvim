-- Jupyter notebooks: jupytext (plain-text .ipynb) + molten (kernel exec) + image.nvim
--
-- Prerequisites (also installed by ./setup when possible):
--   - Python 3.10+ host: pynvim, jupyter_client, ipykernel, jupytext, nbformat
--   - ImageMagick (`magick`/`convert`) for image.nvim
--   - A terminal with Kitty graphics protocol (Kitty, Ghostty, or WezTerm) for
--     inline plots. Apple Terminal / default Windows Terminal cannot render them.
--   - WSL: inline images need ueberzugpp + WSLg/X11, or a Kitty-protocol terminal
--     that supports graphics over the WSL boundary. Otherwise text output still works.

local function nvim_venv_python()
  local data = vim.fn.stdpath("data")
  local candidates = {
    data .. "/venv/bin/python",
    data .. "/venv/Scripts/python.exe", -- Windows/WSL edge installs
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      return path
    end
  end
  return nil
end

--- Jupyter's per-user kernelspec dir (jupyter_core convention; independent of nvim's data dir).
local function jupyter_data_dir()
  if vim.fn.has("mac") == 1 then
    return vim.fn.expand("~/Library/Jupyter")
  elseif vim.fn.has("win32") == 1 then
    return vim.fn.expand(vim.env.APPDATA and (vim.env.APPDATA .. "/jupyter") or "~/AppData/Roaming/jupyter")
  else
    return vim.fn.expand("~/.local/share/jupyter")
  end
end

local GENERIC_VENV_DIR_NAMES = { [".venv"] = true, ["venv"] = true, ["env"] = true, [".env"] = true }

--- venv/.venv is a meaningless kernel name (every project has one); use the project dir instead.
--- Named conda envs (CONDA_PREFIX) are already meaningful, so keep those as-is.
local function venv_kernel_base_name(venv)
  local base = vim.fn.fnamemodify(venv, ":t")
  if GENERIC_VENV_DIR_NAMES[base] then
    local parent = vim.fn.fnamemodify(venv, ":h:t")
    if parent ~= "" then
      return parent
    end
  end
  return base
end

--- Register (once) the active venv/conda env as a Jupyter kernel so `:MoltenInit <name>`
--- actually finds it. Without this, "activate venv then <leader>ji" silently tries to init
--- a kernel literally named after the venv folder (e.g. ".venv"), which never exists.
--- Returns the kernel name on success, or nil (and notifies) on failure.
local function ensure_venv_kernel(venv)
  local py = venv .. "/bin/python"
  if not vim.uv.fs_stat(py) then
    py = venv .. "/Scripts/python.exe"
  end
  if not vim.uv.fs_stat(py) then
    return nil
  end

  -- jupyter_client lowercases kernel names on install, so match that here or the
  -- "already registered?" check below never finds it and reinstalls every time.
  local name = venv_kernel_base_name(venv):gsub("[^%w_.-]", "_"):lower()
  local kernel_json = jupyter_data_dir() .. "/kernels/" .. name .. "/kernel.json"
  if vim.uv.fs_stat(kernel_json) then
    return name
  end

  vim.notify("Registering Jupyter kernel '" .. name .. "' for " .. venv .. " ...", vim.log.levels.INFO)
  local result = vim
    .system({
      py,
      "-m",
      "ipykernel",
      "install",
      "--user",
      "--name=" .. name,
      "--display-name=" .. name .. " (venv)",
    }, { text = true })
    :wait()

  if result.code ~= 0 then
    vim.notify(
      "Could not register kernel for "
        .. venv
        .. ": "
        .. vim.trim(result.stderr or "unknown error")
        .. "\nIs ipykernel installed in this venv? (pip install ipykernel)",
      vim.log.levels.ERROR
    )
    return nil
  end

  return name
end

--- Pick an image.nvim backend from the running terminal / available tools.
--- Prefer Kitty graphics protocol (Kitty, Ghostty, WezTerm); fall back to ueberzug.
local function detect_image_backend()
  if vim.env.KITTY_WINDOW_ID or vim.env.TERM == "xterm-kitty" then
    return "kitty"
  end
  -- Ghostty implements the Kitty graphics protocol
  if vim.env.GHOSTTY_RESOURCES_DIR or vim.env.TERM == "xterm-ghostty" then
    return "kitty"
  end
  if vim.env.WEZTERM_EXECUTABLE or vim.env.TERM_PROGRAM == "WezTerm" or vim.env.TERM == "wezterm" then
    return "kitty"
  end
  local term = (vim.env.TERM or ""):lower()
  if term:find("kitty", 1, true) or term:find("ghostty", 1, true) then
    return "kitty"
  end
  if vim.fn.executable("ueberzugpp") == 1 or vim.fn.executable("ueberzug") == 1 then
    return "ueberzug"
  end
  -- Default: kitty protocol. Images simply will not render in unsupported terminals
  -- (e.g. Apple Terminal); molten text output still works.
  return "kitty"
end

--- Hydrogen / percent style cell under cursor (# %%). Returns start/end line (1-based).
local function hydrogen_cell_range()
  local cur = vim.fn.line(".")
  local start_line = vim.fn.search([[^# %%]], "bcnW")
  if start_line == 0 then
    start_line = 1
  end
  local next_cell = vim.fn.search([[^# %%]], "nW")
  local end_line
  if next_cell == 0 or next_cell <= start_line then
    end_line = vim.fn.line("$")
  else
    end_line = next_cell - 1
  end
  if cur < start_line then
    start_line = 1
  end
  return start_line, end_line
end

local function molten_run_cell()
  local ok, err = pcall(function()
    local s, e = hydrogen_cell_range()
    vim.fn.MoltenEvaluateRange(s, e)
  end)
  if not ok then
    vim.notify("Molten: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function molten_run_cell_and_next()
  molten_run_cell()
  local moved = vim.fn.search([[^# %%]], "W")
  if moved == 0 then
    vim.notify("Molten: no next cell", vim.log.levels.INFO)
  end
end

-- jupytext.nvim shells out to the `jupytext` CLI, which needs a real file to write to, so it
-- always materializes a plaintext sidecar (e.g. foo.py next to foo.ipynb) while a notebook is
-- open. It only self-deletes that sidecar on a clean buffer close (BufUnload), and only if the
-- sidecar didn't already exist before opening — a crash, `:qa!`, or killing the terminal skips
-- that cleanup and leaves the sidecar behind permanently (jupytext then treats it as intentional).
local function jupytext_sidecar_py(ipynb_path)
  return vim.fn.fnamemodify(ipynb_path, ":r") .. ".py"
end

local function ipynb_is_open(ipynb_path)
  local target = vim.fn.fnamemodify(ipynb_path, ":p")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p") == target then
      return true
    end
  end
  return false
end

-- Neovim's 'hidden' option defaults ON, so leaving a notebook's last window (closing the
-- split, switching buffers, quitting) normally just hides the buffer instead of unloading
-- it — and jupytext's sidecar cleanup only runs on BufUnload. That left the .py sidecar
-- sitting there until nvim fully exited. Force ipynb buffers to unload (not hide) the
-- instant they're no longer shown anywhere, so cleanup fires right when you "close" one.
-- Trade-off: if you switch away from a notebook with an attached Molten kernel and back,
-- the buffer's kernel attachment is lost (the kernel process itself keeps running) — just
-- press <leader>ji again to reattach.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function(ev)
    if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":e") == "ipynb" then
      vim.bo[ev.buf].bufhidden = "unload"
    end
  end,
})

vim.api.nvim_create_user_command("JupytextCleanup", function(cmd_opts)
  local dir = cmd_opts.args ~= "" and cmd_opts.args or vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end

  local removed = {}
  for _, ipynb in ipairs(vim.fn.globpath(dir, "*.ipynb", false, true)) do
    if not ipynb_is_open(ipynb) then
      local sidecar = jupytext_sidecar_py(ipynb)
      if vim.uv.fs_stat(sidecar) then
        vim.fn.delete(sidecar)
        table.insert(removed, vim.fn.fnamemodify(sidecar, ":t"))
      end
    end
  end

  if #removed == 0 then
    vim.notify("JupytextCleanup: nothing to clean up in " .. dir, vim.log.levels.INFO)
  else
    vim.notify("JupytextCleanup: removed " .. table.concat(removed, ", "), vim.log.levels.INFO)
  end
end, {
  nargs = "?",
  complete = "dir",
  desc = "Delete stray jupytext .py sidecars for notebooks that aren't currently open",
})

return {
  -- Plain-text pair editing for .ipynb (must not be lazy — BufRead hooks need to exist)
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      -- Hydrogen/percent style keeps filetype=python so basedpyright + ruff keep working.
      style = "hydrogen",
      output_extension = "auto",
      force_ft = nil,
    },
    keys = {
      {
        "<leader>jx",
        "<cmd>JupytextCleanup<cr>",
        desc = "Jupytext: clean up stray .py sidecars",
      },
    },
  },

  -- Terminal image rendering used by molten for plots
  {
    "3rd/image.nvim",
    -- Pin to the first release with the magick_cli processor (no luarocks `magick` needed).
    -- v1.1.0 hard-requires the `magick` LuaRock even when processor = "magick_cli" is set,
    -- and its setup() failure doesn't raise a Lua error (uses nvim_err_writeln), so it
    -- silently breaks image rendering while still reporting itself as configured.
    version = "1.5.1",
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      -- pcall: image.nvim hard-errors in headless / non-graphics terminals (no TIOCGWINSZ).
      -- Molten text output still works without a successful image setup.
      local opts = {
        backend = detect_image_backend(),
        processor = "magick_cli",
        integrations = {
          markdown = { enabled = true },
        },
        max_width = 100,
        max_height = 12,
        -- Required so molten output windows are not percentage-capped incorrectly
        max_height_window_percentage = math.huge,
        max_width_window_percentage = math.huge,
        window_overlap_clear_enabled = true,
        window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
      }

      local ok, err = pcall(function()
        require("image").setup(opts)
      end)
      if ok then
        vim.g.molten_image_provider = "image.nvim"
      else
        vim.g.molten_image_provider = "none"
        vim.schedule(function()
          vim.notify(
            "image.nvim unavailable ("
              .. tostring(err)
              .. "). Molten text output still works; inline plots need Kitty/Ghostty/WezTerm + ImageMagick.",
            vim.log.levels.WARN
          )
        end)
      end
    end,
  },

  -- Interactive Jupyter kernel execution inside Neovim
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    -- Optional dependency: load image.nvim if present, but don't let its failure block molten.
    dependencies = {
      {
        "3rd/image.nvim",
        optional = true,
      },
    },
    build = ":UpdateRemotePlugins",
    -- Eager load so remote plugin commands (MoltenInit, …) are real, not lazy cmd stubs.
    -- Molten is a remote plugin; lazy `cmd =` wrappers shadow the rplugin definitions.
    lazy = false,
    init = function()
      -- python3_host_prog is set early in config/options.lua from the setup venv.
      local py = nvim_venv_python()
      if py and not vim.g.python3_host_prog then
        vim.g.python3_host_prog = py
      end

      -- Start with no image provider; image.nvim config upgrades this on successful setup.
      -- (If we set "image.nvim" here and setup later fails, molten aborts cell runs.)
      vim.g.molten_image_provider = "none"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = true
      vim.g.molten_wrap_output = true
      -- Keep virt text off by default to avoid fighting auto-open float + image rendering
      vim.g.molten_virt_text_output = false
    end,
    config = function()
      -- Ensure rplugin manifest is loaded (needed after first install / :UpdateRemotePlugins)
      pcall(vim.cmd, "runtime! rplugin.vim")
      -- Try loading image.nvim now so molten_image_provider can be upgraded on success.
      pcall(require, "image")
    end,
    keys = {
      {
        "<leader>ji",
        function()
          local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
          local name = venv and ensure_venv_kernel(venv)
          if name then
            vim.cmd("MoltenInit " .. name)
          else
            vim.cmd("MoltenInit")
          end
        end,
        desc = "Molten: init kernel",
      },
      {
        "<leader>jc",
        molten_run_cell,
        desc = "Molten: run cell",
      },
      {
        "<leader>jn",
        molten_run_cell_and_next,
        desc = "Molten: run cell and next",
      },
      {
        "<leader>jv",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "v",
        desc = "Molten: run visual selection",
      },
      {
        "<leader>jo",
        ":noautocmd MoltenEnterOutput<CR>",
        desc = "Molten: open output window",
      },
      {
        "<leader>jh",
        "<cmd>MoltenHideOutput<cr>",
        desc = "Molten: close output window",
      },
      {
        "<leader>jr",
        "<cmd>MoltenRestart!<cr>",
        desc = "Molten: restart kernel",
      },
      {
        "<leader>jI",
        "<cmd>MoltenInterrupt<cr>",
        desc = "Molten: interrupt kernel",
      },
      {
        "<leader>jl",
        "<cmd>MoltenEvaluateLine<cr>",
        desc = "Molten: run line",
      },
    },
  },
}
