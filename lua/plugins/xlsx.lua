-- .xlsx editor: edit the active sheet as a plain-text table, saved back with openpyxl.
--
-- xlsx is a zip of XML, not text, so there's nothing for Neovim to show without a
-- converter. Rather than depend on one of the handful of single-digit-star community
-- xlsx plugins, this shells out to openpyxl (via the same managed venv python already
-- used for molten/jupytext, see jupyter.lua).
--
-- Only the cells you actually change get written back on :w (a diff against the grid
-- as it was when loaded/last saved) -- untouched cells, including formulas, are never
-- touched. That's what makes editing safe: we never re-serialize a whole sheet blindly.
-- A cell you DO edit is written as a plain value (int/float/string), so editing a
-- formula cell or a date/bool cell replaces it with static text/number, same as typing
-- over it in Excel. Very large sheets (over the truncation cap) stay read-only, since a
-- partial view can't be safely diffed/saved.
--
-- Prerequisites (installed by ./setup): the nvim venv's python with openpyxl.

-- xlsx is a zip container, so Neovim's builtin zipPlugin.vim (runtime/plugin/zipPlugin.vim)
-- claims BufReadCmd for *.xlsx by default and would browse it as a raw archive instead.
-- zipPlugin.vim only hardcodes its extension list if g:zipPlugin_ext isn't already set, so
-- predefining it here (verbatim copy of its v33 default, minus *.xlsx) keeps zip-browsing
-- for every other office/archive format (.docx, .zip, .jar, ...) while freeing up .xlsx for
-- our own handler below. This must run before plugin/zipPlugin.vim is sourced, which it is:
-- this file's top level runs synchronously inside lazy.setup() during init.lua, and plugin
-- scripts aren't sourced until a later startup step.
if vim.g.zipPlugin_ext == nil then
  vim.g.zipPlugin_ext = "*.aar,*.apk,*.celzip,*.crtx,*.docm,*.docx,*.dotm,*.dotx,*.ear,*.epub,"
    .. "*.gcsx,*.glox,*.gqsx,*.ja,*.jar,*.kmz,*.odb,*.odc,*.odf,*.odg,*.odi,*.odm,*.odp,*.ods,"
    .. "*.odt,*.otc,*.otf,*.otg,*.oth,*.oti,*.otp,*.ots,*.ott,*.oxt,*.pkpass,*.potm,*.potx,"
    .. "*.ppam,*.ppsm,*.ppsx,*.pptm,*.pptx,*.sldx,*.thmx,*.vdw,*.war,*.whl,*.wsz,*.xap,*.xlam,"
    .. "*.xlsb,*.xlsm,*.xltm,*.xltx,*.xpi,*.zip"
end

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

local function xlsx_python()
  return nvim_venv_python() or (vim.fn.executable("python3") == 1 and "python3" or nil)
end

-- Two modes, picked by argv[3]:
--   read  (default): dumps {sheets, active, rows, truncated_rows, truncated_cols} (or
--     {error}) as JSON on stdout for the given sheet (or the active one).
--   write: reads a JSON list of {row, col, value} edits (1-indexed, matching
--     ws.iter_rows order) from stdin and applies only those cells, preserving
--     everything else (styles, formulas, other sheets) untouched.
-- [==[ ]==], not [[ ]]: the script body contains literal "]]" (e.g. wb[sheets[0]]),
-- which would otherwise terminate a plain [[ long string early.
local XLSX_VIEWER_PY = [==[
import json, re, sys
from datetime import date, datetime, time

MAX_ROWS, MAX_COLS = 5000, 100

def cell_str(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, (datetime, date, time)):
        return v.isoformat()
    return str(v)

def coerce(v):
    if v == "":
        return None
    if re.fullmatch(r"[+-]?\d+", v):
        return int(v)
    try:
        return float(v)
    except ValueError:
        return v

def open_sheet(path, sheet, read_only, data_only):
    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=data_only, read_only=read_only)
    try:
        ws = wb[sheet] if sheet else wb[wb.sheetnames[0]]
    except KeyError:
        raise SystemExit(f"no such sheet: {sheet}")
    return wb, ws

def read_mode(path, sheet):
    try:
        import openpyxl  # noqa: F401 -- import error check before touching the file
    except ImportError:
        print(json.dumps({"error": "openpyxl not installed. Run ./setup, or: pip install openpyxl (in nvim's venv)"}))
        return

    try:
        wb, ws = open_sheet(path, sheet, read_only=True, data_only=True)
    except SystemExit as e:
        print(json.dumps({"error": str(e)}))
        return
    except Exception as e:
        print(json.dumps({"error": f"failed to open workbook: {e}"}))
        return

    sheets = wb.sheetnames
    rows, truncated_rows, truncated_cols = [], False, False
    for i, row in enumerate(ws.iter_rows(values_only=True)):
        if i >= MAX_ROWS:
            truncated_rows = True
            break
        if len(row) > MAX_COLS:
            truncated_cols = True
            row = row[:MAX_COLS]
        rows.append([cell_str(v) for v in row])

    active = ws.title
    wb.close()
    print(json.dumps({
        "sheets": sheets,
        "active": active,
        "rows": rows,
        "truncated_rows": truncated_rows,
        "truncated_cols": truncated_cols,
    }))

def write_mode(path, sheet):
    try:
        edits = json.loads(sys.stdin.read())
    except Exception as e:
        print(json.dumps({"error": f"bad edits payload: {e}"}))
        return

    try:
        # data_only=False so untouched formula cells keep their formula (not the cached
        # value) when the workbook is re-serialized; read_only=False so it's writable.
        wb, ws = open_sheet(path, sheet, read_only=False, data_only=False)
    except SystemExit as e:
        print(json.dumps({"error": str(e)}))
        return
    except Exception as e:
        print(json.dumps({"error": f"failed to open workbook: {e}"}))
        return

    for edit in edits:
        ws.cell(row=edit["row"], column=edit["col"]).value = coerce(edit["value"])

    try:
        wb.save(path)
    except Exception as e:
        print(json.dumps({"error": f"failed to save workbook: {e}"}))
        return
    wb.close()
    print(json.dumps({"ok": True}))

def main():
    path = sys.argv[1]
    sheet = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
    mode = sys.argv[3] if len(sys.argv) > 3 else "read"
    if mode == "write":
        write_mode(path, sheet)
    else:
        read_mode(path, sheet)

main()
]==]

local function viewer_script_path()
  local path = vim.fn.stdpath("data") .. "/xlsx_viewer.py"
  vim.fn.writefile(vim.split(XLSX_VIEWER_PY, "\n"), path)
  return path
end

local CELL_SEP = " │ "

-- Renders `rows` (list of list-of-string) as a plain-text table, columns padded to
-- the widest cell and separated with a box-drawing bar; row 1 gets a header rule.
local function format_table(rows)
  if #rows == 0 then
    return { "(empty sheet)" }
  end

  local ncols = 0
  for _, row in ipairs(rows) do
    ncols = math.max(ncols, #row)
  end

  local widths = {}
  for c = 1, ncols do
    widths[c] = 0
    for _, row in ipairs(rows) do
      widths[c] = math.max(widths[c], vim.fn.strdisplaywidth(row[c] or ""))
    end
  end

  local function render_row(row)
    local parts = {}
    for c = 1, ncols do
      local v = row[c] or ""
      parts[c] = v .. string.rep(" ", widths[c] - vim.fn.strdisplaywidth(v))
    end
    return table.concat(parts, CELL_SEP)
  end

  local lines = { render_row(rows[1]) }
  local rule = {}
  for c = 1, ncols do
    rule[c] = string.rep("─", widths[c])
  end
  table.insert(lines, table.concat(rule, "─┼─"))
  for i = 2, #rows do
    table.insert(lines, render_row(rows[i]))
  end
  return lines
end

-- Inverse of format_table: reads the table lines (buffer content from
-- xlsx_table_start onward), dropping the box-drawing rule line, into a grid of strings.
local function parse_table(buf)
  local start = vim.b[buf].xlsx_table_start
  if not start then
    return nil
  end
  local rows = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, start, -1, false)) do
    if not line:match("^[─┼]*$") then
      local fields = vim.split(line, CELL_SEP, { plain = true })
      for i, f in ipairs(fields) do
        fields[i] = vim.trim(f)
      end
      table.insert(rows, fields)
    end
  end
  return rows
end

-- Re-pads every column to its current widest cell. Editing a cell only changes that
-- one line, so columns drift out of alignment until this runs; parse_table trims each
-- field first, so this is purely cosmetic and never affects what a save diffs/writes.
local function realign_table(buf)
  if vim.b[buf].xlsx_truncated then
    return
  end
  local grid = parse_table(buf)
  if not grid then
    return
  end
  local start = vim.b[buf].xlsx_table_start
  local ok_cur, cur = pcall(vim.api.nvim_win_get_cursor, 0)
  vim.api.nvim_buf_set_lines(buf, start, -1, false, format_table(grid))
  if ok_cur then
    pcall(vim.api.nvim_win_set_cursor, 0, cur)
  end
end

-- Inserts a blank row (right number of CELL_SEP-delimited empty fields for the
-- table's current column count) above/below the cursor line, then starts insert mode
-- in it. Typing a bare empty line wouldn't parse back into per-column cells, so this
-- is what makes 'o'/'O' do something sane in an xlsx buffer.
local function insert_row(buf, below)
  if vim.b[buf].xlsx_truncated then
    vim.notify("Xlsx: sheet too large to edit safely (truncated view)", vim.log.levels.ERROR)
    return
  end
  local ncols = 1
  local grid = parse_table(buf)
  if grid then
    for _, row in ipairs(grid) do
      ncols = math.max(ncols, #row)
    end
  end

  local cells = {}
  for i = 1, ncols do
    cells[i] = ""
  end
  local new_line = table.concat(cells, CELL_SEP)

  local cur_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
  local insert_at = below and cur_line + 1 or cur_line
  -- Never land inside/above the header row + box-drawing rule line.
  insert_at = math.max(insert_at, vim.b[buf].xlsx_table_start + 2)

  vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { insert_at + 1, 0 })
  vim.cmd("startinsert")
end

--- 1-indexed column the cursor sits in, counting CELL_SEP occurrences before it.
local function cursor_col_index(line, cursor_byte_col)
  local before = line:sub(1, cursor_byte_col)
  local count, pos = 0, 1
  while true do
    local s = before:find(CELL_SEP, pos, true)
    if not s then
      break
    end
    count = count + 1
    pos = s + #CELL_SEP
  end
  return count + 1
end

--- Byte offset right after the n-th CELL_SEP in `line` (0 if n <= 0).
local function nth_sep_end(line, n)
  if n <= 0 then
    return 0
  end
  local pos, found = 1, 0
  while found < n do
    local s, e = line:find(CELL_SEP, pos, true)
    if not s then
      return #line
    end
    found = found + 1
    pos = e + 1
  end
  return pos - 1
end

-- Inserts a blank column before/after whichever column the cursor is in (every row
-- gets one new empty field at that position), then starts insert mode in the cursor
-- row's new cell. Other rows' cells in the new column stay blank until edited.
local function insert_column(buf, after)
  if vim.b[buf].xlsx_truncated then
    vim.notify("Xlsx: sheet too large to edit safely (truncated view)", vim.log.levels.ERROR)
    return
  end
  local grid = parse_table(buf)
  if not grid then
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_row, cur_byte_col = cur[1], cur[2]
  local cur_line = vim.api.nvim_buf_get_lines(buf, cur_row - 1, cur_row, false)[1] or ""
  local col_idx = cursor_col_index(cur_line, cur_byte_col)
  local target_col = after and col_idx + 1 or col_idx

  for _, row in ipairs(grid) do
    table.insert(row, math.min(target_col, #row + 1), "")
  end

  local start = vim.b[buf].xlsx_table_start
  vim.api.nvim_buf_set_lines(buf, start, -1, false, format_table(grid))

  local new_line = vim.api.nvim_buf_get_lines(buf, cur_row - 1, cur_row, false)[1] or ""
  vim.api.nvim_win_set_cursor(0, { cur_row, nth_sep_end(new_line, target_col - 1) })
  vim.cmd("startinsert")
end

-- Cell-by-cell diff of two string grids. Cells that only exist in one grid (rows/cols
-- added or removed) are included too, against "" on the missing side, so removed
-- content is explicitly cleared rather than silently left in place.
local function diff_grids(old, new)
  local edits = {}
  for r = 1, math.max(#old, #new) do
    local orow, nrow = old[r] or {}, new[r] or {}
    for c = 1, math.max(#orow, #nrow) do
      local ov, nv = orow[c] or "", nrow[c] or ""
      if ov ~= nv then
        table.insert(edits, { row = r, col = c, value = nv })
      end
    end
  end
  return edits
end

--- Loads `sheet` (or the active sheet if nil) from the workbook at `path` into `buf`.
--- Stores sheet list/active name/original grid as buffer vars for ]s / [s and :w.
local function render_sheet(buf, path, sheet)
  local py = xlsx_python()
  if not py then
    vim.notify("Xlsx: no python found for openpyxl. Run ./setup first.", vim.log.levels.ERROR)
    return
  end

  local result = vim.system({ py, viewer_script_path(), path, sheet or "" }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("Xlsx: viewer script failed: " .. vim.trim(result.stderr or "unknown error"), vim.log.levels.ERROR)
    return
  end

  local ok, data = pcall(vim.json.decode, vim.trim(result.stdout or ""))
  if not ok or not data then
    vim.notify("Xlsx: could not parse viewer output", vim.log.levels.ERROR)
    return
  end
  if data.error then
    vim.notify("Xlsx: " .. data.error, vim.log.levels.ERROR)
    return
  end

  local idx = 1
  for i, s in ipairs(data.sheets) do
    if s == data.active then
      idx = i
      break
    end
  end

  local truncated = data.truncated_rows or data.truncated_cols
  local lines = {
    string.format(
      "# %s  (sheet %d/%d)   ]s next sheet   [s prev sheet%s",
      data.active,
      idx,
      #data.sheets,
      truncated and "   [READ-ONLY: too large to edit safely]"
        or "   o/O row   <leader>c/C column   <leader>f format   :w save"
    ),
    "",
  }
  local table_start = #lines
  vim.list_extend(lines, format_table(data.rows))

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "xlsx"
  vim.bo[buf].modifiable = not truncated
  vim.bo[buf].readonly = truncated and true or false

  vim.b[buf].xlsx_path = path
  vim.b[buf].xlsx_sheets = data.sheets
  vim.b[buf].xlsx_active = data.active
  vim.b[buf].xlsx_table_start = table_start
  vim.b[buf].xlsx_orig_grid = data.rows
  vim.b[buf].xlsx_truncated = truncated
end

local function cycle_sheet(buf, dir)
  if vim.bo[buf].modified then
    vim.notify("Xlsx: unsaved changes -- :w to save, or :e! to discard, before switching sheets", vim.log.levels.WARN)
    return
  end
  local sheets = vim.b[buf].xlsx_sheets
  if not sheets or #sheets <= 1 then
    vim.notify("Xlsx: only one sheet", vim.log.levels.INFO)
    return
  end
  local idx = 1
  for i, s in ipairs(sheets) do
    if s == vim.b[buf].xlsx_active then
      idx = i
      break
    end
  end
  idx = ((idx - 1 + dir) % #sheets) + 1
  render_sheet(buf, vim.b[buf].xlsx_path, sheets[idx])
end

--- Diffs the buffer's current table against the grid as loaded/last saved, and writes
--- only the changed cells back into the real workbook. Returns true on success.
local function save_sheet(buf)
  if vim.b[buf].xlsx_truncated then
    vim.notify("Xlsx: sheet too large to edit safely (truncated view)", vim.log.levels.ERROR)
    return false
  end

  local new_grid = parse_table(buf)
  if not new_grid then
    vim.notify("Xlsx: could not parse table for saving", vim.log.levels.ERROR)
    return false
  end

  local edits = diff_grids(vim.b[buf].xlsx_orig_grid or {}, new_grid)
  if #edits == 0 then
    return true
  end

  local py = xlsx_python()
  if not py then
    vim.notify("Xlsx: no python found for openpyxl. Run ./setup first.", vim.log.levels.ERROR)
    return false
  end

  local result = vim
    .system(
      { py, viewer_script_path(), vim.b[buf].xlsx_path, vim.b[buf].xlsx_active, "write" },
      { text = true, stdin = vim.json.encode(edits) }
    )
    :wait()

  if result.code ~= 0 then
    vim.notify("Xlsx: save failed: " .. vim.trim(result.stderr or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  local ok, resp = pcall(vim.json.decode, vim.trim(result.stdout or ""))
  if not ok or not resp or resp.error then
    vim.notify("Xlsx: save failed: " .. (ok and resp.error or "bad response"), vim.log.levels.ERROR)
    return false
  end

  vim.b[buf].xlsx_orig_grid = new_grid
  return true
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*.xlsx",
  callback = function(ev)
    render_sheet(ev.buf, vim.fn.fnamemodify(ev.match, ":p"), nil)
  end,
})

-- Must be a real BufWriteCmd (not just 'nomodifiable') so :w dispatches here instead of
-- trying to write the rendered text over the real workbook bytes. 'buftype=nofile' would
-- block :w before this even runs, so the buffer is left as a normal file-backed buffer.
vim.api.nvim_create_autocmd("BufWriteCmd", {
  pattern = "*.xlsx",
  callback = function(ev)
    local buf = ev.buf
    if save_sheet(buf) then
      vim.bo[buf].modified = false
      vim.notify("Xlsx: saved " .. vim.b[buf].xlsx_active, vim.log.levels.INFO)
    end
  end,
})

-- Re-align columns automatically once a cell edit is done (InsertLeave) and right
-- before every save, so the table never has to be manually tidied before :w.
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*.xlsx",
  callback = function(ev)
    realign_table(ev.buf)
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.xlsx",
  callback = function(ev)
    realign_table(ev.buf)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "xlsx",
  callback = function(ev)
    local buf = ev.buf
    vim.keymap.set("n", "]s", function()
      cycle_sheet(buf, 1)
    end, { buffer = buf, desc = "Xlsx: next sheet" })
    vim.keymap.set("n", "[s", function()
      cycle_sheet(buf, -1)
    end, { buffer = buf, desc = "Xlsx: prev sheet" })
    -- Same key as the global LSP-format map (config/lsp.lua); no LSP ever attaches
    -- to this filetype, so it's free to mean "format" here too.
    vim.keymap.set("n", "<leader>f", function()
      realign_table(buf)
    end, { buffer = buf, desc = "Xlsx: realign columns" })
    -- A bare 'o'/'O' would insert an empty line that doesn't parse into per-column
    -- cells; these insert a properly delimited blank row instead, same muscle memory.
    vim.keymap.set("n", "o", function()
      insert_row(buf, true)
    end, { buffer = buf, desc = "Xlsx: insert row below" })
    vim.keymap.set("n", "O", function()
      insert_row(buf, false)
    end, { buffer = buf, desc = "Xlsx: insert row above" })
    -- Mirrors o/O: lowercase = after (right), uppercase = before (left).
    vim.keymap.set("n", "<leader>c", function()
      insert_column(buf, true)
    end, { buffer = buf, desc = "Xlsx: insert column after" })
    vim.keymap.set("n", "<leader>C", function()
      insert_column(buf, false)
    end, { buffer = buf, desc = "Xlsx: insert column before" })
  end,
})

return {}
