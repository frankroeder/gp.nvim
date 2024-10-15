local ui = require("parrot.ui")
local utils = require("parrot.utils")

local M = {}

-- Buffer target resolution
---@param params table | string # table with args or string args
---@return number # buf target
function M.resolve_buffer_target(params)
  local args = type(params) == "table" and (params.args or "") or params
  local target_map = {
    popup = ui.BufTarget.popup,
    split = ui.BufTarget.split,
    vsplit = ui.BufTarget.vsplit,
    tabnew = ui.BufTarget.tabnew,
  }
  return target_map[args] or ui.BufTarget.current
end

---@param buf number | nil
function M.prepare_markdown_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Set buffer options
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  -- Set text wrapping
  vim.api.nvim_command("setlocal wrap linebreak")

  -- Set up auto-save
  vim.api.nvim_command("autocmd TextChanged,InsertLeave <buffer=" .. buf .. "> silent! write")

  -- Ensure normal mode
  vim.api.nvim_command("stopinsert")
  utils.feedkeys("<esc>", "xn")
end

return M
