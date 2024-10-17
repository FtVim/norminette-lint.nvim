local M = {}

local group = vim.api.nvim_create_augroup("Norminette", { clear = true })
local ns = vim.api.nvim_create_namespace("norminette")
local enabled = false
local line_cache = {} -- Cache to track lines content

-- Default options
local default_options = {
  enable_on_start = false, -- Whether to enable the linter when Neovim starts
  keybinding = "<leader>Fn" -- Default keybinding for enabling the linter
}

-- Function to get current buffer lines
local function get_buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Function to get the appropriate file extension for the temp file
local function get_file_extension(bufnr)
  local file_name = vim.api.nvim_buf_get_name(bufnr)
  return vim.fn.fnamemodify(file_name, ":e") -- Gets the extension of the current file
end

-- Function to create a temporary file for .h files with the same name as the original in a temp directory
local function create_temp_file_for_h(bufnr)
  local original_file_path = vim.api.nvim_buf_get_name(bufnr)
  local file_name = vim.fn.fnamemodify(original_file_path, ":t")

  -- Create a temporary directory without altering the file name
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")

  -- Combine the temp directory with the original file name (keeping the name intact)
  local temp_path = temp_dir .. "/" .. file_name

  -- Write the current buffer content to the temporary file
  local lines = get_buffer_lines(bufnr)
  vim.fn.writefile(lines, temp_path)

  return temp_path
end

-- Function to save buffer to a temporary file for norminette execution
local function save_temp_file(bufnr)
  local file_ext = get_file_extension(bufnr)

  if file_ext ~= "c" and file_ext ~= "h" then
    return nil
  end

  -- Create a temporary file with the exact original name for .h files
  if file_ext == "h" then
    return create_temp_file_for_h(bufnr)
  end

  -- For .c files, use a generic temp file
  local temp_path = vim.fn.tempname() .. ".c"
  local lines = get_buffer_lines(bufnr)
  vim.fn.writefile(lines, temp_path)
  return temp_path
end

-- Function to run norminette and populate diagnostics
local function set_diagnostics(bufnr)
  vim.diagnostic.reset(ns, bufnr) -- Clear previous diagnostics

  vim.diagnostic.config({
      virtual_text = {
          prefix = '●',
          spacing = 0,
          severity = vim.diagnostic.severity.ERROR,
          virt_text_pos = 'eol',
      },
  })
  local temp_file = save_temp_file(bufnr)
  if not temp_file then return end
  local output = vim.fn.system("norminette " .. temp_file)

  -- Delete the temp file after running norminette
  vim.fn.delete(temp_file)

  local lines = vim.split(output, "\n")
  local diagnostics = {}

  for _, line in ipairs(lines) do
    local parts = vim.split(line, ":")
    if #parts < 3 then goto continue end

    local rowline = string.match(parts[3], '%d[%d]*')
    local row = tonumber(rowline) - 1
    local message = parts[5]

    table.insert(diagnostics, {
      lnum = row,
      col = 0,
      severity = vim.diagnostic.severity.ERROR,
      message = "Norminette: " .. message:gsub("^%s+", "")
    })
    ::continue::
  end

  -- Set diagnostics for the buffer
  vim.diagnostic.set(ns, bufnr, diagnostics)

  -- Update cache of lines after diagnostics
  line_cache[bufnr] = get_buffer_lines(bufnr)
end

-- Function to check if a line has changed compared to the cache
local function line_changed(bufnr, line_num)
  local cached_lines = line_cache[bufnr]
  local current_lines = get_buffer_lines(bufnr)

  -- If the line content differs from the cached version, it's considered changed
  return cached_lines and cached_lines[line_num] ~= current_lines[line_num]
end

-- Autocommand function to handle line changes or file save
local function set_autocmd()
  -- Run diagnostics on buffer write (after the file is saved)
  vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter"}, {
    pattern = {"*.c", "*.h"},
    group = group,
    callback = function(event)
      if not enabled then return end
      set_diagnostics(event.buf)
    end
  })

  -- Detect line changes without saving the file
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    pattern = {"*.c", "*.h"},
    group = group,
    callback = function(event)
      if not enabled then return end

      -- Check for line changes and re-run diagnostics if any line changed
      local bufnr = event.buf
      local changed = false

      -- Loop through each line to detect changes
      local current_lines = get_buffer_lines(bufnr)
      for i = 0, #current_lines - 1 do
        if line_changed(bufnr, i) then
          changed = true
          break
        end
      end

      if changed then
        set_diagnostics(bufnr)
      end
    end
  })
end

-- Enable function
function M.enable()
  if not enabled then
    enabled = true
    set_autocmd() -- Reset autocommands when enabling
    -- Run diagnostics immediately after enabling
    local bufnr = vim.api.nvim_get_current_buf()
    vim.notify("Enabling Norminette Linter", "Info", { title = "Norminette Linter" })
    if not set_diagnostics(bufnr) then
      return nil
    end
  end
end

-- Disable function
function M.disable()
  if enabled then
    enabled = false
    vim.api.nvim_clear_autocmds({ group = group }) -- Clear autocommands to disable
    vim.diagnostic.reset(ns) -- Clear diagnostics when disabled
    vim.notify("Disabling Norminette Linter", "Info", { title = "Norminette Linter" })
  end
end

-- Toggle function
function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.status()
  print(enabled)
  return enabled
end

-- Setup function to initialize the plugin with options
function M.setup(opts)
  -- Merge user-provided options with defaults
  opts = opts or {}
  opts = vim.tbl_extend("force", default_options, opts)

  vim.api.nvim_set_keymap('n', opts.keybinding, "<CMD>lua require('norminette-lint').toggle()<CR>", { noremap = true, silent = true,
  desc = "Toggle Norminette Linter" })
  if opts.enable_on_start then
    M.enable() -- Enable the linter if configured to do so on startup
  end
end

return M

