local utils = require("parrot.utils")
local chatutils = require("parrot.chat_utils")
local logger = require("parrot.logger")

--- BufferManager Module
-- Handles buffer-related operations such as preparing chat and context buffers,
-- setting buffer options, and managing auto-save functionality.
local BufferManager = {}
BufferManager.__index = BufferManager

--- Creates a new BufferManager instance.
-- @param options table Configuration options.
-- @param state State instance for managing persistent state.
-- @return BufferManager
function BufferManager:new(options, state)
  local instance = setmetatable({
    options = options,
    state = state,
    auto_save_groups = {}, -- Tracks autocmd groups per buffer
  }, BufferManager)
  return instance
end

--- Prepares a chat buffer.
-- Sets up the buffer with necessary options, prepares markdown formatting,
-- configures auto-save, and updates the plugin state.
-- @param buf number Buffer number.
-- @param file_name string Name of the chat file.
function BufferManager:prepare_chat(buf, file_name)
  if not utils.is_chat(buf, file_name, self.options.chat_dir) then
    return
  end

  -- Prepare the buffer with markdown settings
  chatutils.prepare_markdown_buffer(buf)

  -- Set up auto-save for the buffer
  self:setup_auto_save(buf)

  -- Remember the last opened chat file in the state
  self.state:set_last_chat(file_name)
  self.state:refresh(self.options.available_providers, self.options.available_models)
end

--- Prepares a context buffer.
-- Configures buffers that hold additional context information.
-- @param buf number Buffer number.
-- @param file_name string Name of the context file.
function BufferManager:prepare_context(buf, file_name)
  if not utils.ends_with(file_name, ".parrot.md") then
    return
  end

  if buf ~= vim.api.nvim_get_current_buf() then
    return
  end

  chatutils.prepare_markdown_buffer(buf)
end

--- Sets up auto-save for a buffer.
-- Configures autocmds to automatically save the buffer on text changes and insert leave events.
-- Prevents multiple autocmd registrations for the same buffer.
-- @param buf number Buffer number.
function BufferManager:setup_auto_save(buf)
  -- Ensure that auto-save is not already set up for this buffer
  if self.auto_save_groups[buf] then
    return
  end

  local group_name = "PrtAutoSave_" .. buf
  -- Ensure group_name is less than or equal to 30 characters
  group_name = group_name:sub(1, 30)

  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group, -- Use the group ID
    buffer = buf,
    callback = function()
      local ok, err = pcall(function()
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent! write")
        end)
      end)
      if not ok then
        logger.error(string.format("Auto-save failed for buffer %d: %s", buf, err))
      end
    end,
  })

  self.auto_save_groups[buf] = group
end

--- Cleans up auto-save autocmds for a buffer.
-- Removes autocmd groups associated with a buffer to prevent memory leaks.
-- @param buf number Buffer number.
function BufferManager:cleanup_auto_save(buf)
  local group = self.auto_save_groups[buf]
  if group then
    pcall(vim.api.nvim_del_augroup_by_id, group)
    self.auto_save_groups[buf] = nil
  end
end

--- Cleans up all resources.
-- Removes all autocmd groups managed by BufferManager.
function BufferManager:cleanup()
  for buf, group in pairs(self.auto_save_groups) do
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end
  self.auto_save_groups = {}
end

--- Prepares a markdown buffer.
-- Sets buffer options, text wrapping, and auto-save.
-- @param buf number Buffer number.
function BufferManager:prepare_markdown_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  -- Set text wrapping
  vim.api.nvim_buf_set_option(buf, "wrap", true)
  vim.api.nvim_buf_set_option(buf, "linebreak", true)

  -- Set up auto-save for the buffer
  self:setup_auto_save(buf)

  -- Ensure normal mode
  vim.api.nvim_command("stopinsert")
  utils.feedkeys("<esc>", "xn")
end

return BufferManager
