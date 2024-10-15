local utils = require("parrot.utils")
local logger = require("parrot.logger")
local ui = require("parrot.ui")

--- CommandManager Module
-- Handles the registration and setup of commands and keybindings for the parrot.nvim plugin.
local CommandManager = {}
CommandManager.__index = CommandManager

--- Creates a new CommandManager instance.
-- @param options table Configuration options.
-- @param chat_handler ChatHandler instance to delegate actions.
-- @return CommandManager
function CommandManager:new(options, chat_handler)
  local instance = setmetatable({
    options = options,
    chat_handler = chat_handler,
    commands = {}, -- Stores command definitions
  }, CommandManager)
  return instance
end

--- Prepares and registers all commands by iterating over ui.Target.
function CommandManager:prepare_commands()
  for name, target in pairs(ui.Target) do
    -- Uppercase first letter to form the command name
    local command = name:gsub("^%l", string.upper)

    -- Determine the appropriate model based on the target
    local model_obj = self.chat_handler:get_model("command")
    if target == ui.Target.popup then
      model_obj = self.chat_handler:get_model("chat")
    end

    -- Define the command callback function
    local cmd = function(params)
      -- Choose the template based on the range and target
      local template = self.options.template_command
      if params.range == 2 then
        template = self.options.template_selection
        -- Select custom templates for specific targets
        if target == ui.Target.rewrite then
          template = self.options.template_rewrite
        elseif target == ui.Target.append then
          template = self.options.template_append
        elseif target == ui.Target.prepend then
          template = self.options.template_prepend
        end
      end

      -- Render the command prefix using templates
      local cmd_prefix = utils.template_render_from_list(
        self.options.command_prompt_prefix_template,
        { ["{{llm}}"] = model_obj.name }
      )

      -- Delegate the prompt handling to ChatHandler
      self.chat_handler:prompt(params, target, model_obj, cmd_prefix, utils.trim(template), true)
    end

    -- Store the command in the commands table
    self.commands[command] = command

    -- Register the command with Neovim and set up keybindings
    self:add_command(command, function(params)
      cmd(params)
    end)
  end
end

--- Adds and registers a single command.
-- @param command string Command name.
-- @param cmd function Command callback function.
function CommandManager:add_command(command, cmd)
  if not command or not cmd then
    logger.error("CommandManager:add_command requires both command name and callback function.")
    return
  end

  -- Register the user command with Neovim
  vim.api.nvim_create_user_command(command, function(params)
    cmd(params)
  end, { nargs = "*", range = true })

  logger.debug(string.format("Registered command: %s", command))

  -- Extract the base name without "Chat" prefix if present for keybinding configuration
  local base_command = command:gsub("^Chat", "")
  local shortcut_key = self.options["chat_shortcut_" .. base_command:lower()]

  if shortcut_key and shortcut_key.shortcut then
    self:setup_keybinding(command, shortcut_key)
  end
end

--- Sets up keybindings for a specific command.
-- @param command string Command name.
-- @param keybind table Keybinding definition containing modes, shortcut, and description.
function CommandManager:setup_keybinding(command, keybind)
  if not keybind or not keybind.modes or not keybind.shortcut then
    logger.error(string.format("Invalid keybind configuration for command: %s", command))
    return
  end

  for _, mode in ipairs(keybind.modes) do
    -- Define a keymap callback to execute the command
    local callback = function()
      vim.api.nvim_command(command .. "<CR>")
      -- Exit insert mode if in insert mode
      if mode == "i" then
        vim.api.nvim_command("stopinsert")
      end
    end

    -- Set the keymap with buffer-local scope if specified
    local opts = { noremap = true, silent = true, desc = keybind.desc or ("Execute " .. command) }
    if keybind.buffer then
      vim.api.nvim_buf_set_keymap(keybind.buffer, mode, keybind.shortcut, "", { callback = callback, noremap = opts.noremap, silent = opts.silent, desc = opts.desc })
    else
      vim.api.nvim_set_keymap(mode, keybind.shortcut, "", { callback = callback, noremap = opts.noremap, silent = opts.silent, desc = opts.desc })
    end

    logger.debug(string.format("Set keybinding for command '%s' in mode '%s' with shortcut '%s'", command, mode, keybind.shortcut))
  end
end

--- Cleans up all registered commands and keybindings.
function CommandManager:cleanup()
  for command_name, _ in pairs(self.commands) do
    pcall(vim.api.nvim_del_user_command, command_name)
    logger.info(string.format("Unregistered command: %s", command_name))
    -- Note: Neovim does not provide a direct way to remove keybindings programmatically.
    -- To remove keybindings, you would need to track them and manually unset them if necessary.
  end
end
--- Handles the execution of a command.
---@param params table Parameters passed from the command invocation.
---@param target ui.Target The target UI component.
---@param model_obj Model The language model to use.
---@param cmd_prefix string The command prompt prefix.
---@param template string The template to use for the prompt.
function CommandManager:handle_command(params, target, model_obj, cmd_prefix, template)
  -- Mode specific logic
  local handler
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local start_line = params.line1
  local end_line = params.line2
  local cursor = vim.api.nvim_win_get_cursor(0)
  local prefix = cmd_prefix

  if target == ui.Target.rewrite then
    -- Delete selection
    vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, {})
    -- Prepare handler
    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, start_line - 1, true, prefix, cursor):create_handler()
  elseif target == ui.Target.append then
    -- Move cursor to the end of the selection
    vim.api.nvim_win_set_cursor(0, { end_line, 0 })
    -- Put newline after selection
    vim.api.nvim_put({ "" }, "l", true, true)
    -- Prepare handler
    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, end_line, true, prefix, cursor):create_handler()
  elseif target == ui.Target.prepend then
    -- Move cursor to the start of the selection
    vim.api.nvim_win_set_cursor(0, { start_line, 0 })
    -- Put newline before selection
    vim.api.nvim_put({ "" }, "l", false, true)
    -- Prepare handler
    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, start_line - 1, true, prefix, cursor):create_handler()
  elseif target == ui.Target.popup then
    self.chat_handler:toggle_close(self.chat_handler._toggle_kind.popup)
    -- Create a new buffer
    local popup_close = nil
    buf, win, popup_close, _ = ui.create_popup(
      nil,
      self.chat_handler._plugin_name .. " popup (close with <esc>/<C-c>)",
      function(w, h)
        local top = self.options.style_popup_margin_top or 2
        local bottom = self.options.style_popup_margin_bottom or 8
        local left = self.options.style_popup_margin_left or 1
        local right = self.options.style_popup_margin_right or 1
        local max_width = self.options.style_popup_max_width or 160
        local ww = math.min(w - (left + right), max_width)
        local wh = h - (top + bottom)
        return ww, wh, top, (w - ww) / 2
      end,
      { on_leave = true, escape = true },
      { border = self.options.style_popup_border or "single" }
    )
    -- Set the created buffer as the current buffer
    vim.api.nvim_set_current_buf(buf)
    -- Set the filetype to markdown
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
    -- Better text wrapping
    vim.api.nvim_command("setlocal wrap linebreak")
    -- Prepare handler
    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, 0, false, "", false):create_handler()
    self.chat_handler:toggle_add(self.chat_handler._toggle_kind.popup, { win = win, buf = buf, close = popup_close })
  elseif type(target) == "table" then
    if target.type == ui.Target.new().type then
      vim.cmd("split")
      win = vim.api.nvim_get_current_win()
    elseif target.type == ui.Target.vnew().type then
      vim.cmd("vsplit")
      win = vim.api.nvim_get_current_win()
    elseif target.type == ui.Target.tabnew().type then
      vim.cmd("tabnew")
      win = vim.api.nvim_get_current_win()
    end

    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(buf)

    local group = utils.create_augroup("PrtScratchSave" .. utils.uuid(), { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      buffer = buf,
      group = group,
      callback = function(ctx)
        vim.api.nvim_set_option_value("buftype", "", { buf = ctx.buf })
        vim.api.nvim_buf_set_name(ctx.buf, ctx.file)
        vim.api.nvim_command("w!")
        vim.api.nvim_del_augroup_by_id(ctx.group)
      end,
    })

    local ft = target.filetype or vim.api.nvim_buf_get_option(0, 'filetype')
    vim.api.nvim_set_option_value("filetype", ft, { buf = buf })

    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, 0, false, "", cursor):create_handler()
  else
    -- Default handler
    handler = ResponseHandler:new(self.chat_handler.queries, buf, win, 0, true, prefix, cursor):create_handler()
  end

  -- Delegate the prompt handling to ChatHandler with the prepared handler
  self.chat_handler:prompt(params, target, model_obj, cmd_prefix, utils.trim(template), true, handler)
end

return CommandManager
