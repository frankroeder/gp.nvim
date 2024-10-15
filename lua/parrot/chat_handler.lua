local utils = require("parrot.utils")
local futils = require("parrot.file_utils")
local logger = require("parrot.logger")
local Pool = require("parrot.pool")
local Queries = require("parrot.queries")
local State = require("parrot.state")
local chatutils = require("parrot.chat_utils")
local ui = require("parrot.ui")
local init_provider = require("parrot.provider").init_provider
local Spinner = require("parrot.spinner")
local Job = require("plenary.job")
local pft = require("plenary.filetype")
local ResponseHandler = require("parrot.response_handler")
local BufferManager = require("parrot.buffer_manager")
local CommandManager = require("parrot.command_manager")
local ToggleManager = require("parrot.toggle_manager")

local ChatHandler = {}
ChatHandler.__index = ChatHandler

function ChatHandler:new(options, providers, available_providers, available_models, commands)
  local state = State:new(options.state_dir)
  state:refresh(available_providers, available_models)
  return setmetatable({
    _plugin_name = "parrot.nvim",
    options = options,
    providers = providers,
    current_provider = { chat = nil, command = nil },
    pool = Pool:new(),
    queries = Queries:new(),
    buffer_manager = BufferManager:new(options, state),
		toggle_manager = ToggleManager:new(),
    commands = commands,
    state = state,
    _toggle = {},
    _toggle_kind = {
      unknown = 0,
      chat = 1,
      popup = 2,
      context = 3,
    },
    available_providers = available_providers,
    available_models = available_models,
    history = {
      last_selection = nil,
      last_command = nil,
      last_line1 = nil,
      last_line2 = nil,
    },
  }, self)
end

--- Retrieves status information about the current buffer.
---@return table { is_chat = boolean, prov = table | nil, model = string }
function ChatHandler:get_status_info()
  local buf = vim.api.nvim_get_current_buf()
  local file_name = vim.api.nvim_buf_get_name(buf)
  local is_chat = utils.is_chat(buf, file_name, self.options.chat_dir)
  local model_obj = self:get_model(is_chat and "chat" or "command")
  return { is_chat = is_chat, prov = self.current_provider, model = model_obj.name }
end

--- Sets the current provider for chat or command.
---@param selected_prov string Selected provider name.
---@param is_chat boolean True for chat provider, false for command provider.
function ChatHandler:set_provider(selected_prov, is_chat)
  local endpoint = self.providers[selected_prov].endpoint
  local api_key = self.providers[selected_prov].api_key
  local _prov = init_provider(selected_prov, endpoint, api_key)
  self.current_provider[is_chat and "chat" or "command"] = _prov
  self.state:set_provider(_prov.name, is_chat)
  self.state:refresh(self.available_providers, self.available_models)
  self.command_manager:prepare_commands() -- Delegate to CommandManager
end

--- Retrieves the current provider for chat or command.
---@param is_chat boolean True for chat provider, false for command provider.
---@return table | nil Provider table or nil if not found.
function ChatHandler:get_provider(is_chat)
  local current_prov = self.current_provider[is_chat and "chat" or "command"]
  if not current_prov then
    local prov = self.state:get_provider(is_chat)
    if not prov then
      logger.error(string.format("No provider found for %s", is_chat and "chat" or "command"))
      return nil
    end
    self:set_provider(prov, is_chat)
    current_prov = self.current_provider[is_chat and "chat" or "command"]
  end
  return current_prov
end

--- Handles buffer events by delegating to BufferManager.
function ChatHandler:buf_handler()
  local gid = utils.create_augroup("PrtBufHandler", { clear = true })

  utils.autocmd({ "BufEnter" }, nil, function(event)
    local buf = event.buf

    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local file_name = vim.api.nvim_buf_get_name(buf)

    -- Delegate to BufferManager
    self.buffer_manager:prepare_chat(buf, file_name)
    self.buffer_manager:prepare_context(buf, file_name)
  end, gid)
end

function ChatHandler:setup_chat_prompt(buf)
  if self.options.chat_prompt_buf_type then
    vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })
    vim.fn.prompt_setprompt(buf, "")
    vim.fn.prompt_setcallback(buf, function()
      self:chat_respond({ args = "" })
    end)
  end
end

function ChatHandler:setup_chat_commands(buf)
  local range_commands = {
    {
      command = "ChatRespond",
      modes = self.options.chat_shortcut_respond.modes,
      shortcut = self.options.chat_shortcut_respond.shortcut,
      comment = "Parrot Chat Respond",
    },
    {
      command = "ChatNew",
      modes = self.options.chat_shortcut_new.modes,
      shortcut = self.options.chat_shortcut_new.shortcut,
      comment = "Parrot Chat New",
    },
  }
  for _, rc in ipairs(range_commands) do
    self:setup_chat_command(buf, rc)
  end
end

function ChatHandler:setup_chat_command(buf, command_info)
  local cmd = self.options.cmd_prefix .. command_info.command .. "<cr>"
  for _, mode in ipairs(command_info.modes) do
    if mode == "n" or mode == "i" then
      utils.set_keymap({ buf }, mode, command_info.shortcut, function()
        vim.api.nvim_command(self.options.cmd_prefix .. command_info.command)
        vim.api.nvim_command("stopinsert")
        utils.feedkeys("<esc>", "xn")
      end, command_info.comment)
    else
      utils.set_keymap({ buf }, mode, command_info.shortcut, ":<C-u>'<,'>" .. cmd, command_info.comment)
    end
  end
end

function ChatHandler:setup_chat_shortcuts(buf)
  local ds = self.options.chat_shortcut_delete
  utils.set_keymap({ buf }, ds.modes, ds.shortcut, function()
    self:chat_delete()
  end, "Parrot Chat Delete")

  local ss = self.options.chat_shortcut_stop
  utils.set_keymap({ buf }, ss.modes, ss.shortcut, function()
    self:stop()
  end, "Parrot Chat Stop")
end

--- Delegates context preparation to BufferManager.
---@param buf number Buffer number.
---@param file_name string Name of the context file.
function ChatHandler:prep_context(buf, file_name)
  self.buffer_manager:prepare_context(buf, file_name)
end

--- Toggles (closes) a specific toggle kind using ToggleManager.
---@param kind number Kind of toggle.
---@return boolean True if toggle was closed.
function ChatHandler:toggle_close(kind)
  return self.toggle_manager:close(kind)
end

--- Adds a toggle using ToggleManager.
---@param kind number Kind of toggle.
---@param toggle table Table containing `win`, `buf`, and `close` information.
function ChatHandler:toggle_add(kind, toggle)
  self.toggle_manager:add(kind, toggle)
end

--- Resolves a toggle kind string to its numeric representation using ToggleManager.
---@param kind string String representation of the toggle kind.
---@return number Numeric kind of the toggle.
function ChatHandler:toggle_resolve(kind)
  return self.toggle_manager:resolve(kind)
end

--- Retrieves the model information based on the model type.
---@param model_type string "chat" or "command".
---@return table { name, system_prompt, provider }
function ChatHandler:get_model(model_type)
  local is_chat = model_type == "chat"
  local prov = self:get_provider(is_chat)
  if not prov then
    logger.error("Provider not available for model type: " .. model_type)
    return {}
  end
  local model = self.state:get_model(prov.name, model_type)
  local system_prompt = self.options.system_prompt[model_type] or ""
  return {
    name = model,
    system_prompt = system_prompt,
    provider = prov,
  }
end

--- Prepares commands by delegating to CommandManager.
function ChatHandler:prepare_commands()
  if not self.command_manager then
    self.command_manager = CommandManager:new(self.options, self)
  end
  self.command_manager:prepare_commands()
end

--- Adds a command by delegating to CommandManager.
-- @param command string Command name.
-- @param cmd function Command callback.
function ChatHandler:addCommand(command, cmd)
  self.command_manager:add_command(command, cmd)
end

--- Stops all ongoing processes by killing associated jobs.
---@param signal number | nil Signal to send to the processes.
function ChatHandler:stop(signal)
  if self.pool:is_empty() then
    return
  end

  for _, process_info in self.pool:ipairs() do
    if process_info.job.handle ~= nil and not process_info.job.handle:is_closing() then
      vim.uv.kill(process_info.job.pid, signal or 15)
    end
  end

  self.pool = Pool:new()
end

--- Handles context-related actions.
---@param params table Parameters for the context action.
function ChatHandler:context(params)
  self:toggle_close(self._toggle_kind.popup)
  -- If there is no selection, try to close context toggle
  if params.range ~= 2 then
    if self:toggle_close(self._toggle_kind.context) then
      return
    end
  end

  local cbuf = vim.api.nvim_get_current_buf()

  local file_name = ""
  local buf = utils.get_buffer(".parrot.md")
  if buf then
    file_name = vim.api.nvim_buf_get_name(buf)
  else
    local git_root = futils.find_git_root()
    if git_root == "" then
      logger.warning("Not in a git repository")
      return
    end
    file_name = git_root .. "/.parrot.md"
  end

  if vim.fn.filereadable(file_name) ~= 1 then
    vim.fn.writefile({ "Additional context is provided below.", "" }, file_name)
  end

  params.args = params.args or ""
  if params.args == "" then
    params.args = self.options.toggle_target
  end
  local target = chatutils.resolve_buffer_target(params)
  buf = self:open_buf(file_name, target, self._toggle_kind.context, true)

  if params.range == 2 then
    utils.append_selection(params, cbuf, buf, utils.trim(self.options.template_selection))
  end

  utils.feedkeys("G", "xn")
end

--- Opens a buffer based on the provided parameters.
---@param file_name string Name of the file to open.
---@param target number Buffer target.
---@param kind number Kind of toggle.
---@param toggle boolean Whether to toggle the buffer.
---@return number Buffer number.
function ChatHandler:open_buf(file_name, target, kind, toggle)
  target = target or ui.BufTarget.current

  -- Close previous popup if it exists
  self:toggle_close(self._toggle_kind.popup)

  if toggle then
    self:toggle_close(kind)
  end

  local close, buf, win

  if target == ui.BufTarget.popup then
    local old_buf = utils.get_buffer(file_name)

    buf, win, close, _ = ui.create_popup(
      old_buf,
      self._plugin_name .. " Popup",
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
      { on_leave = false, escape = false, persist = true, keep_buf = true },
      { border = self.options.style_popup_border or "single" }
    )

    if not toggle then
      self:toggle_add(self._toggle_kind.popup, { win = win, buf = buf, close = close })
    end

    if old_buf == nil then
      -- Read file into buffer and force write it
      vim.api.nvim_command("silent 0read " .. file_name)
      vim.api.nvim_command("silent file " .. file_name)
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
    else
      -- Move cursor to the beginning of the file and scroll to the end
      utils.feedkeys("ggG", "xn")
    end

    -- Delete whitespace lines at the end of the file
    local last_content_line = utils.last_content_line(buf)
    vim.api.nvim_buf_set_lines(buf, last_content_line, -1, false, {})
    -- Insert a new line at the end of the file
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    vim.api.nvim_command("silent write! " .. file_name)
  elseif target == ui.BufTarget.split then
    vim.api.nvim_command("split " .. file_name)
  elseif target == ui.BufTarget.vsplit then
    vim.api.nvim_command("vsplit " .. file_name)
  elseif target == ui.BufTarget.tabnew then
    vim.api.nvim_command("tabnew " .. file_name)
  else
    -- Check if it's already open in a buffer
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(b) == file_name then
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(w) == b then
            vim.api.nvim_set_current_win(w)
            return b
          end
        end
      end
    end

    -- Open in new buffer
    vim.api.nvim_command("edit " .. file_name)
  end

  buf = vim.api.nvim_get_current_buf()
  win = vim.api.nvim_get_current_win()
  close = close or function() end

  if not toggle then
    return buf
  end

  if target == ui.BufTarget.split or target == ui.BufTarget.vsplit then
    close = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

  if target == ui.BufTarget.tabnew then
    close = function()
      if vim.api.nvim_win_is_valid(win) then
        local tab = vim.api.nvim_win_get_tabpage(win)
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_command("tabclose")
      end
    end
  end

  self:toggle_add(kind, { win = win, buf = buf, close = close })

  return buf
end

--- Creates a new chat file.
---@param params table Parameters for creating a new chat.
---@param toggle boolean Whether to toggle the chat buffer.
---@param chat_prompt string Optional chat prompt.
---@return number Buffer number.
function ChatHandler:_new_chat(params, toggle, chat_prompt)
  self:toggle_close(self._toggle_kind.popup)

  -- Prepare filename
  local time = os.date("%Y-%m-%d.%H-%M-%S")
  local stamp = tostring(math.floor(vim.uv.hrtime() / 1000000) % 1000)
  local cbuf = vim.api.nvim_get_current_buf()
  -- Make sure stamp is 3 digits
  while #stamp < 3 do
    stamp = "0" .. stamp
  end
  time = time .. "." .. stamp
  local filename = self.options.chat_dir .. "/" .. time .. ".md"

  if chat_prompt then
    local filetype = pft.detect(vim.api.nvim_buf_get_name(cbuf), {})
    local fname = vim.api.nvim_buf_get_name(cbuf)
    local filecontent = table.concat(vim.api.nvim_buf_get_lines(cbuf, 0, -1, false), "\n")
    local multifilecontent = utils.get_all_buffer_content()
    chat_prompt = utils.template_render(chat_prompt, "", "", filetype, fname, filecontent, multifilecontent)
    chat_prompt = "- system: " .. utils.trim(chat_prompt):gsub("\n", " ") .. "\n"
  else
    chat_prompt = ""
  end

  local template = utils.template_render_from_list(utils.trim(self.options.chat_template), {
    ["{{user}}"] = self.options.chat_user_prefix,
    ["{{optional}}"] = chat_prompt,
  })
  -- Escape underscores (for markdown)
  template = template:gsub("_", "\\_")
  -- Strip leading and trailing newlines
  template = template:gsub("^%s*(.-)%s*$", "%1") .. "\n"

  -- Create chat file
  vim.fn.writefile(vim.split(template, "\n"), filename)
  local target = chatutils.resolve_buffer_target(params)
  local buf = self:open_buf(filename, target, self._toggle_kind.chat, toggle)

  if params.range == 2 then
    utils.append_selection(params, cbuf, buf, utils.trim(self.options.template_selection))
  end
  utils.feedkeys("G", "xn")
  return buf
end

--- Creates a new chat.
---@param params table Parameters for creating a new chat.
---@param chat_prompt string Optional chat prompt.
---@return number Buffer number.
function ChatHandler:chat_new(params, chat_prompt)
  -- If chat toggle is open, close it and start a new one
  if self:toggle_close(self._toggle_kind.chat) then
    params.args = params.args or ""
    if params.args == "" then
      params.args = self.options.toggle_target
    end
    return self:_new_chat(params, true, chat_prompt)
  end

  if params.args == "" then
    params.args = self.options.toggle_target
  end
  return self:_new_chat(params, false, chat_prompt)
end

--- Toggles the chat buffer.
---@param params table Parameters for toggling the chat.
function ChatHandler:chat_toggle(params)
  self:toggle_close(self._toggle_kind.popup)
  if self:toggle_close(self._toggle_kind.chat) and params.range ~= 2 then
    return
  end

  -- Create new chat file otherwise
  params.args = params.args or ""
  if params.args == "" then
    params.args = self.options.toggle_target
  end

  -- If the range is 2, we want to create a new chat file with the selection
  if params.range ~= 2 then
    local last_chat_file = self.state:get_last_chat()
    if last_chat_file and vim.fn.filereadable(last_chat_file) == 1 then
      self:open_buf(last_chat_file, chatutils.resolve_buffer_target(params), self._toggle_kind.chat, true)
      return
    end
  end

  self:_new_chat(params, true)
end

--- Pastes selected text into the last chat.
---@param params table Parameters for pasting.
function ChatHandler:chat_paste(params)
  -- If there is no selection, do nothing
  if params.range ~= 2 then
    logger.warning("Please select some text to paste into the chat.")
    return
  end

  -- Get current buffer
  local cbuf = vim.api.nvim_get_current_buf()

  local last_chat_file = self.state:get_last_chat()
  if last_chat_file and vim.fn.filereadable(last_chat_file) ~= 1 then
    -- Skip rest since new chat will handle snippet on its own
    self:chat_new(params)
    return
  end

  params.args = params.args or ""
  if params.args == "" then
    params.args = self.options.toggle_target
  end
  local target = chatutils.resolve_buffer_target(params)
  local buf = utils.get_buffer(last_chat_file)
  local win_found = false
  if buf then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        vim.api.nvim_set_current_win(w)
        vim.api.nvim_set_current_buf(buf)
        win_found = true
        break
      end
    end
  end
  buf = win_found and buf or self:open_buf(last_chat_file, target, self._toggle_kind.chat, true)

  utils.append_selection(params, cbuf, buf, utils.trim(self.options.template_selection))
  utils.feedkeys("G", "xn")
end

--- Deletes the current chat file.
function ChatHandler:chat_delete()
  -- Get buffer and file
  local buf = vim.api.nvim_get_current_buf()
  local file_name = vim.api.nvim_buf_get_name(buf)

  -- Check if file is in the chat dir
  if not utils.starts_with(file_name, self.options.chat_dir) then
    logger.warning("File " .. vim.inspect(file_name) .. " is not in chat dir")
    return
  end

  -- Delete without confirmation
  if not self.options.chat_confirm_delete then
    futils.delete_file(file_name, self.options.chat_dir)
    return
  end

  -- Ask for confirmation
  vim.ui.input({ prompt = "Delete " .. file_name .. "? [y/N] " }, function(input)
    if input and input:lower() == "y" then
      futils.delete_file(file_name, self.options.chat_dir)
    end
  end)
end

--- Handles chat responses by delegating to the querying system.
---@param params table Parameters for responding.
function ChatHandler:_chat_respond(params)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local model_obj = self:get_model("chat")
  local model_name = model_obj.name

  if not self.pool:unique_for_buffer(buf) then
    logger.warning("Another parrot process is already running for this buffer.")
    return
  end

  -- Go to normal mode
  vim.cmd("stopinsert")

  -- Get all lines
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Check if file looks like a chat file
  local file_name = vim.api.nvim_buf_get_name(buf)
  if not utils.is_chat(buf, file_name, self.options.chat_dir) then
    logger.warning("File " .. vim.inspect(file_name) .. " does not look like a chat file")
    return
  end

  -- Headers are fields before first message ---
  local headers = {}
  local header_end = nil
  local line_idx = 1 -- Lua tables are 1-based
  -- Parse headers
  for _, line in ipairs(lines) do
    -- First line starts with ---
    if line:sub(1, 3) == "---" then
      header_end = line_idx
      break
    end
    -- Parse header fields
    local key, value = line:match("^[-#] (%w+): (.*)")
    if key ~= nil then
      headers[key] = value
    end

    line_idx = line_idx + 1
  end

  if header_end == nil then
    logger.error("Error while parsing headers: --- not found. Check your chat template.")
    return
  end

  -- Messages need role and content
  local messages = {}
  local role = ""
  local content = ""

  -- Iterate over lines
  local start_index = header_end + 1
  local end_index = #lines
  if params.range == 2 then
    start_index = math.max(start_index, params.line1)
    end_index = math.min(end_index, params.line2)
  end

  if headers.system and headers.system:match("%S") then
    model_name = model_name .. " & custom system prompt"
  end

  local query_prov = model_obj.provider
  query_prov:set_model(model_obj.name)

  local llm_prefix = self.options.llm_prefix
  local llm_suffix = "[{{llm}}]"
  local provider = query_prov.name
  llm_suffix = utils.template_render_from_list(llm_suffix, { ["{{llm}}"] = model_name .. " - " .. provider })

  for index = start_index, end_index do
    local line = lines[index]
    if line:sub(1, #self.options.chat_user_prefix) == self.options.chat_user_prefix then
      table.insert(messages, { role = role, content = content })
      role = "user"
      content = line:sub(#self.options.chat_user_prefix + 1)
    elseif line:sub(1, #llm_prefix) == llm_prefix then
      table.insert(messages, { role = role, content = content })
      role = "assistant"
      content = ""
    elseif role ~= "" then
      content = content .. "\n" .. line
    end
  end
  -- Insert last message not handled in loop
  table.insert(messages, { role = role, content = content })

  -- Replace first empty message with system prompt
  content = ""
  if headers.system and headers.system:match("%S") then
    content = headers.system
  else
    content = model_obj.system_prompt
  end
  if content:match("%S") then
    -- Make it multiline again if it contains escaped newlines
    content = content:gsub("\\n", "\n")
    messages[1] = { role = "system", content = content }
  end

  -- Write assistant prompt
  local last_content_line = utils.last_content_line(buf)
  vim.api.nvim_buf_set_lines(buf, last_content_line, last_content_line, false, { "", llm_prefix .. llm_suffix, "" })

  local spinner = nil
  if self.options.enable_spinner then
    spinner = Spinner:new(self.options.spinner_type)
    spinner:start("calling API...")
  end

  -- Call the model and write response
  self:query(
    buf,
    query_prov,
    utils.prepare_payload(messages, model_obj.name, self.providers[query_prov.name].params["chat"]),
    ResponseHandler
      :new(self.queries, buf, win, utils.last_content_line(buf), true, "", not self.options.chat_free_cursor)
      :create_handler(),
    vim.schedule_wrap(function(qid)
      if self.options.enable_spinner and spinner then
        spinner:stop()
      end
      local qt = self.queries:get(qid)
      if not qt then
        return
      end

      -- Write user prompt
      last_content_line = utils.last_content_line(buf)
      utils.undojoin(buf)
      vim.api.nvim_buf_set_lines(
        buf,
        last_content_line,
        last_content_line,
        false,
        { "", "", self.options.chat_user_prefix, "" }
      )

      -- Delete whitespace lines at the end of the file
      last_content_line = utils.last_content_line(buf)
      utils.undojoin(buf)
      vim.api.nvim_buf_set_lines(buf, last_content_line, -1, false, {})
      -- Insert a new line at the end of the file
      utils.undojoin(buf)
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })

      -- If topic is ?, then generate it
      if headers.topic == "?" then
        -- Insert last model response
        table.insert(messages, { role = "assistant", content = qt.response })

        local topic_prov = model_obj.provider

        -- Ask model to generate topic/title for the chat
        local topic_prompt = self.providers[topic_prov.name].topic_prompt
        if topic_prompt ~= "" then
          table.insert(messages, { role = "user", content = topic_prompt })
        end

        -- Prepare invisible buffer for the model to write to
        local topic_buf = vim.api.nvim_create_buf(false, true)
        local topic_resp_handler = ResponseHandler:new(self.queries, topic_buf, nil, 0, false, "", false)
        local topic_handler = topic_resp_handler:create_handler()
        topic_prov:set_model(self.providers[topic_prov.name].topic.model)

        local topic_spinner = nil
        if self.options.enable_spinner then
          topic_spinner = Spinner:new(self.options.spinner_type)
          topic_spinner:start("summarizing...")
        end
        logger.debug(vim.inspect({
          location = "ChatHandler:query",
          messages = messages,
          topic_prov = topic_prov,
          payload = utils.prepare_payload(
            messages,
            self.providers[topic_prov.name].topic.model,
            self.providers[topic_prov.name].topic.params
          ),
        }))
        -- Call the model
        self:query(
          nil,
          topic_prov,
          utils.prepare_payload(
            messages,
            self.providers[topic_prov.name].topic.model,
            self.providers[topic_prov.name].topic.params
          ),
          topic_handler,
          vim.schedule_wrap(function()
            if self.options.enable_spinner and topic_spinner then
              topic_spinner:stop()
            end
            -- Get topic from invisible buffer
            local topic = vim.api.nvim_buf_get_lines(topic_buf, 0, -1, false)[1]
            -- Close invisible buffer
            vim.api.nvim_buf_delete(topic_buf, { force = true })
            -- Strip whitespace from ends of topic
            topic = topic:gsub("^%s*(.-)%s*$", "%1")
            -- Strip dot from end of topic
            topic = topic:gsub("%.$", "")

            -- If topic is empty do not replace it
            if topic == "" then
              return
            end

            -- Replace topic in current buffer
            utils.undojoin(buf)
            vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
          end)
        )
      end

      if not self.options.chat_free_cursor then
        local line = vim.api.nvim_buf_line_count(buf)
        utils.cursor_to_line(line, buf, win)
      end
      vim.cmd("doautocmd User PrtDone")
    end)
  )
end

--- Responds to chat inputs.
---@param params table Parameters for responding.
function ChatHandler:chat_respond(params)
  if params.args == "" then
    self:_chat_respond(params)
    return
  end

  -- Ensure args is a single positive number
  local n_requests = tonumber(params.args)
  if n_requests == nil or math.floor(n_requests) ~= n_requests or n_requests <= 0 then
    logger.warning("args for ChatRespond should be a single positive number, not: " .. params.args)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cur_index = #lines
  while cur_index > 0 and n_requests > 0 do
    if lines[cur_index]:sub(1, #self.options.chat_user_prefix) == self.options.chat_user_prefix then
      n_requests = n_requests - 1
    end
    cur_index = cur_index - 1
  end

  params.range = 2
  params.line1 = cur_index + 1
  params.line2 = #lines
  self:_chat_respond(params)
end

--- Opens the chat file finder using fzf-lua or native UI.
function ChatHandler:chat_finder()
  local has_fzf, fzf_lua = pcall(require, "fzf-lua")

  local filename_from_selection = function(selected)
    return string.match(selected[1], "(%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d%d%d%.md)")
  end

  if has_fzf then
    local actions = require("fzf-lua").defaults.actions.files
    actions["ctrl-p"] = function(selected)
      local filename = filename_from_selection(selected)
      return self:open_buf(self.options.chat_dir .. "/" .. filename, ui.BufTarget.popup, self._toggle_kind.chat, false)
    end
    -- Add custom action to delete chat files
    actions["ctrl-d"] = function(selected)
      local filename = filename_from_selection(selected)
      if not filename then
        logger.warning("No valid filename selected for deletion.")
        return
      end
      if vim.fn.confirm(string.format("Are you sure you want to delete '%s'?", filename), "&Yes\n&No", 2) == 1 then
        local success, err = futils.delete_file(self.options.chat_dir .. "/" .. filename, self.options.chat_dir)
        if success then
          logger.info(string.format("Deleted chat file: %s", filename))
        else
          logger.error(string.format("Failed to delete '%s': %s", filename, err))
        end
      end
    end

    -- Set default action based on toggle_target
    if self.options.toggle_target == "popup" then
      actions["default"] = actions["ctrl-p"]
    elseif self.options.toggle_target == "split" then
      actions["default"] = actions["ctrl-s"]
    elseif self.options.toggle_target == "vsplit" then
      actions["default"] = actions["ctrl-v"]
    elseif self.options.toggle_target == "tabnew" then
      actions["default"] = actions["ctrl-t"]
    end

    fzf_lua.fzf_exec("rg --no-heading topic --type=md", {
      cwd = self.options.chat_dir,
      prompt = "Chat selection ❯",
      fzf_opts = self.options.fzf_lua_opts,
      previewer = "builtin",
      fn_transform = function(x)
        return require("fzf-lua").make_entry.file(x, { file_icons = true, color_icons = true })
      end,
      actions = actions,
    })
    return
  else
    local scan = require("plenary.scandir") -- Ensure plenary.scandir is available
    local chat_files = scan.scan_dir(self.options.chat_dir, { depth = 1, search_pattern = "%d+%.md$" })
    vim.ui.select(chat_files, {
      prompt = "Select your chat file:",
      format_item = function(item)
        local read_first_line = function(it)
          local file = io.open(it, "r")
          if not file then
            logger.error("Failed to open file: " .. it)
            return ""
          end
          local first_line = file:read("*l")
          file:close()
          return first_line or ""
        end
        return read_first_line(item)
      end,
    }, function(selected_chat)
      if selected_chat == nil then
        logger.warning("Invalid chat file selection.")
        return
      end
      self:open_buf(
        selected_chat,
        chatutils.resolve_buffer_target(self.options.toggle_target),
        self._toggle_kind.chat,
        false
      )
    end)
  end
end

--- Switches the current provider.
---@param selected_prov string Selected provider name.
---@param is_chat boolean True for chat provider, false for command provider.
function ChatHandler:switch_provider(selected_prov, is_chat)
  if selected_prov == nil then
    logger.warning("Empty provider selection")
    return
  end

  if self.providers[selected_prov] then
    self:set_provider(selected_prov, is_chat)
    logger.info("Switched to provider: " .. selected_prov)
    return
  else
    logger.error(
      string.format(
        "Provider '%s' not found. Available providers: %s",
        selected_prov,
        table.concat(self.available_providers, ", ")
      )
    )
    return
  end
end

--- Handles provider selection via command or UI.
---@param params table Parameters for provider selection.
function ChatHandler:provider(params)
  local prov_arg = string.gsub(params.args, "^%s*(.-)%s*$", "%1")
  local has_fzf, fzf_lua = pcall(require, "fzf-lua")
  local buf = vim.api.nvim_get_current_buf()
  local file_name = vim.api.nvim_buf_get_name(buf)
  local is_chat = utils.is_chat(buf, file_name, self.options.chat_dir)
  if prov_arg ~= "" then
    self:switch_provider(prov_arg, is_chat)
  elseif has_fzf then
    fzf_lua.fzf_exec(self.available_providers, {
      prompt = "Provider selection ❯",
      fzf_opts = self.options.fzf_lua_opts,
      actions = {
        ["default"] = function(selected)
          self:switch_provider(selected[1], is_chat)
        end,
      },
    })
  else
    vim.ui.select(self.available_providers, {
      prompt = "Select your provider:",
    }, function(selected_prov)
      self:switch_provider(selected_prov, is_chat)
    end)
  end
end

--- Switches the model for chat or command.
---@param is_chat boolean True for chat model, false for command model.
---@param selected_model string Selected model name.
---@param prov table Provider table.
function ChatHandler:switch_model(is_chat, selected_model, prov)
  if selected_model == nil then
    logger.warning("Empty model selection")
    return
  end
  if is_chat then
    self.state:set_model(prov.name, selected_model, "chat")
    logger.info("Chat model: " .. selected_model)
  else
    self.state:set_model(prov.name, selected_model, "command")
    logger.info("Command model: " .. selected_model)
  end
  self.state:refresh(self.available_providers, self.available_models)
  self.command_manager:prepare_commands() -- Delegate to CommandManager
end

--- Handles model selection via command or UI.
---@param params table Parameters for model selection.
function ChatHandler:model(params)
  local buf = vim.api.nvim_get_current_buf()
  local file_name = vim.api.nvim_buf_get_name(buf)
  local is_chat = utils.is_chat(buf, file_name, self.options.chat_dir)
  local prov = self:get_provider(is_chat)
  local model_name = string.gsub(params.args, "^%s*(.-)%s*$", "%1")
  local has_fzf, fzf_lua = pcall(require, "fzf-lua")
  local fetch_online = self.options.online_model_selection

  if model_name ~= "" then
    self:switch_model(is_chat, model_name, prov)
  elseif has_fzf then
    fzf_lua.fzf_exec(prov:get_available_models(fetch_online), {
      prompt = "Model selection ❯",
      fzf_opts = self.options.fzf_lua_opts,
      actions = {
        ["default"] = function(selected)
          if #selected == 0 then
            logger.warning("No model selected")
            return
          end
          local selected_model = selected[1]
          self:switch_model(is_chat, selected_model, prov)
        end,
      },
    })
  else
    vim.ui.select(prov:get_available_models(fetch_online), {
      prompt = "Select your model:",
    }, function(selected_model)
      self:switch_model(is_chat, selected_model, prov)
    end)
  end
end

--- Retries the last command action.
---@param params table Parameters for retrying.
function ChatHandler:retry(params)
  if self.history.last_line1 == nil and self.history.last_line2 == nil then
    return logger.error("No history available to retry: " .. vim.inspect(self.history))
  end
  vim.api.nvim_command("normal! u")
  logger.debug("ChatHandler:retry - `self.history`: " .. vim.inspect(self.history))
  params.line1 = self.history.last_line1
  params.line2 = self.history.last_line2
  params.range = 2
  local model_obj = self:get_model("command")
  local template = ""
  if self.history.last_target == ui.Target.rewrite then
    template = self.options.template_rewrite
  elseif self.history.last_target == ui.Target.append then
    template = self.options.template_append
  elseif self.history.last_target == ui.Target.prepend then
    template = self.options.template_prepend
  else
    logger.error("Invalid last target: " .. tostring(self.history.last_target))
  end
  self:prompt(params, self.history.last_target, model_obj, nil, utils.trim(template), false)
end

--- Prompts the user and sends the request to the model.
---@param params table Parameters for prompting.
---@param target table | number Buffer target.
---@param model_obj table Model information.
---@param prompt string Optional prompt for user input.
---@param template string Template for generating the user prompt.
---@param reset_history boolean Whether to reset history.
function ChatHandler:prompt(params, target, model_obj, prompt, template, reset_history)
  -- If target is a function, call it to get the actual target
  if type(target) == "function" then
    target = target()
  end

  logger.debug("ChatHandler:prompt - `reset_history`: " .. tostring(reset_history))
  if reset_history == nil or reset_history then
    self.history = {
      last_selection = nil,
      last_command = nil,
      last_line1 = nil,
      last_line2 = nil,
    }
  end

  target = target or ui.Target.enew()

  -- Get current buffer and window
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  if not self.pool:unique_for_buffer(buf) then
    logger.warning("Another parrot process is already running for this buffer.")
    return
  end

  -- Defaults to normal mode
  local selection = nil
  local prefix = ""
  local start_line = vim.api.nvim_win_get_cursor(0)[1]
  local end_line = start_line

  -- Handle range selection
  if params.range == 2 then
    start_line = params.line1
    end_line = params.line2
    local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)

    local min_indent = nil
    local use_tabs = false
    -- Measure minimal common indentation for lines with content
    for i, line in ipairs(lines) do
      lines[i] = line
      -- Skip whitespace-only lines
      if not line:match("^%s*$") then
        local indent = line:match("^%s*")
        -- Check if indentation uses tabs
        if indent:match("\t") then
          use_tabs = true
        end
        if min_indent == nil or #indent < min_indent then
          min_indent = #indent
        end
      end
    end
    if min_indent == nil then
      min_indent = 0
    end
    prefix = string.rep(use_tabs and "\t" or " ", min_indent)

    for i, line in ipairs(lines) do
      lines[i] = line:sub(min_indent + 1)
    end

    selection = table.concat(lines, "\n")

    if selection == "" then
      logger.warning("Please select some text to rewrite")
      return
    end
    self.history.last_target = target
    self.history.last_line1 = start_line
    self.history.last_line2 = end_line
    self.history.last_selection = selection
  end

  self._selection_first_line = start_line
  self._selection_last_line = end_line

  local callback = function(command)
    if self.history.last_command then
      logger.debug("LAST COMMAND in use " .. self.history.last_command)
      command = self.history.last_command
    end
    -- Dummy handler
    local handler = function() end
    -- Default on_exit strips trailing backticks if response was markdown snippet
    local on_exit = function(qid)
      local qt = self.queries:get(qid)
      if not qt then
        return
      end
      -- If buffer is not valid, return
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local flc, llc
      local fl = qt.first_line
      local ll = qt.last_line
      -- Remove empty lines from the start and end of the response
      while true do
        -- Get content of first_line and last_line
        flc = vim.api.nvim_buf_get_lines(buf, fl, fl + 1, false)[1]
        llc = vim.api.nvim_buf_get_lines(buf, ll, ll + 1, false)[1]

        if not flc or not llc then
          break
        end

        local flm = flc:match("%S")
        local llm = llc:match("%S")

        -- Break loop if both lines contain non-whitespace characters
        if flm and llm then
          break
        end

        -- Break loop if lines are equal
        if fl >= ll then
          break
        end

        if not flm then
          utils.undojoin(buf)
          vim.api.nvim_buf_set_lines(buf, fl, fl + 1, false, {})
        else
          utils.undojoin(buf)
          vim.api.nvim_buf_set_lines(buf, ll, ll + 1, false, {})
        end
        ll = ll - 1
      end

      -- If fl and ll start with triple backticks, remove these lines
      if flc and llc and flc:match("^%s*```") and llc:match("^%s*```") then
        -- Remove first line with undojoin
        utils.undojoin(buf)
        vim.api.nvim_buf_set_lines(buf, fl, fl + 1, false, {})
        -- Remove last line
        utils.undojoin(buf)
        vim.api.nvim_buf_set_lines(buf, ll - 1, ll, false, {})
        ll = ll - 2
      end
      qt.first_line = fl
      qt.last_line = ll

      -- Option to not select response automatically
      if not self.options.command_auto_select_response then
        return
      end

      -- Don't select popup response
      if target == ui.Target.popup then
        return
      end

      -- Default works for rewrite and enew
      local start = fl
      local finish = ll

      if target == ui.Target.append then
        start = self._selection_first_line - 1
      end

      if target == ui.Target.prepend then
        finish = self._selection_last_line + ll - fl
      end

      -- Select from first_line to last_line
      vim.api.nvim_win_set_cursor(0, { start + 1, 0 })
      vim.api.nvim_command("normal! V")
      vim.api.nvim_win_set_cursor(0, { finish + 1, 0 })
    end

    -- Prepare messages
    local messages = {}
    local filetype = pft.detect(vim.api.nvim_buf_get_name(buf), {})
    local filename = vim.api.nvim_buf_get_name(buf)
    local prov = model_obj.provider
    self.history.last_command = command
    local sys_prompt = utils.template_render(model_obj.system_prompt, command, selection, filetype, filename)
    sys_prompt = sys_prompt or ""

    if sys_prompt ~= "" then
      local repo_instructions = futils.find_repo_instructions()
      if repo_instructions ~= "" and sys_prompt ~= "" then
        -- Append the repository instructions from .parrot.md to the system prompt
        sys_prompt = sys_prompt .. "\n" .. repo_instructions
      end
      table.insert(messages, { role = "system", content = sys_prompt })
    end

    local filecontent = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local multifilecontent = utils.get_all_buffer_content()
    local user_prompt =
      utils.template_render(template, command, selection, filetype, filename, filecontent, multifilecontent)
    table.insert(messages, { role = "user", content = user_prompt })
    logger.debug("ChatHandler:prompt - `user_prompt`: " .. user_prompt)

    -- Cancel possible visual mode before calling the model
    utils.feedkeys("<esc>", "xn")

    local cursor = true
    if not self.options.command_auto_select_response then
      cursor = false
    end

    -- Mode-specific logic delegated to CommandManager
    self.command_manager:handle_command(target, buf, win, start_line, end_line, prefix, cursor, messages)

    -- Call the model and write the response
    prov:set_model(model_obj.name)

    local spinner = nil
    if self.options.enable_spinner then
      spinner = Spinner:new(self.options.spinner_type)
      spinner:start("calling API...")
    end
    self:query(
      buf,
      prov,
      utils.prepare_payload(messages, model_obj.name, self.providers[prov.name].params["command"]),
      handler,
      vim.schedule_wrap(function(qid)
        if self.options.enable_spinner and spinner then
          spinner:stop()
        end
        on_exit(qid)
        vim.cmd("doautocmd User PrtDone")
      end)
    )
  end

  vim.schedule(function()
    local args = params.args or ""
    if args:match("%S") then
      callback(args)
      return
    end

    -- If prompt is not provided, run the command directly
    if not prompt or prompt == "" then
      callback(nil)
      return
    end

    local input_function = self.options.user_input_ui == "buffer" and ui.input
      or self.options.user_input_ui == "native" and vim.ui.input
    if input_function then
      input_function({ prompt = prompt }, function(input)
        if not input or input == "" or input:match("^%s*$") then
          return
        end
        callback(input)
      end)
    else
      logger.error("Invalid user input UI option: " .. self.options.user_input_ui)
    end
  end)
end

--- Sends a query to the provider's API.
---@param buf number | nil Buffer number.
---@param provider table Provider information.
---@param payload table Payload for the API.
---@param handler function Response handler function.
---@param on_exit function | nil Optional on_exit handler.
function ChatHandler:query(buf, provider, payload, handler, on_exit)
  if type(handler) ~= "function" then
    logger.error(
      string.format("query() expects a handler function, but got %s:\n%s", type(handler), vim.inspect(handler))
    )
    return
  end

  if not provider:verify() then
    logger.error("Provider verification failed")
    return
  end

  local qid = utils.uuid()
  self.queries:add(qid, {
    timestamp = os.time(),
    buf = buf,
    provider = provider.name,
    payload = payload,
    handler = handler,
    on_exit = on_exit,
    response = "",
    first_line = -1,
    last_line = -1,
    ns_id = nil,
    ex_id = nil,
  })

  self.queries:cleanup(8, 60)

  local curl_params = vim.deepcopy(self.options.curl_params or {})
  payload = provider:preprocess_payload(payload)
  local args = {
    "--no-buffer",
    "--silent",
    "-H",
    "accept: application/json",
    "-H",
    "content-type: application/json",
    "-d",
    vim.json.encode(payload),
  }

  for _, arg in ipairs(args) do
    table.insert(curl_params, arg)
  end

  for _, parg in ipairs(provider:curl_params()) do
    table.insert(curl_params, parg)
  end

  local job = Job:new({
    command = "curl",
    args = curl_params,
    on_exit = function(response, exit_code)
      logger.debug("on_exit: " .. vim.inspect(response:result()))
      if exit_code ~= 0 then
        logger.error("An error occurred calling curl: " .. table.concat(curl_params, " "))
        if on_exit then
          on_exit(qid)
        end
        return
      end
      local result = response:result()
      result = utils.parse_raw_response(result)
      provider:process_onexit(result)

      if response.handle and not response.handle:is_closing() then
        response.handle:close()
      end

      if on_exit then
        on_exit(qid)
      end
      local qt = self.queries:get(qid)
      if qt and qt.ns_id and qt.buf then
        vim.schedule(function()
          pcall(vim.api.nvim_buf_clear_namespace, qt.buf, qt.ns_id, 0, -1)
        end)
      end
      self.pool:remove(response.pid)
    end,
    on_stdout = function(_, data)
      logger.debug("on_stdout: " .. vim.inspect(data))
      local qt = self.queries:get(qid)
      if not qt then
        return
      end

      local lines = vim.split(data, "\n")
      for _, line in ipairs(lines) do
        local raw_json = string.gsub(line, "^data:", "")
        local content = provider:process_stdout(raw_json)
        if content then
          qt.response = qt.response .. content
          handler(qid, content)
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        logger.error("Curl stderr: " .. table.concat(data, "\n"))
      end
    end,
  })

  -- Handle job start failure
  local ok, err = pcall(function()
    job:start()
  end)
  if not ok then
    logger.error(string.format("Failed to start curl job: %s", err))
    if on_exit then
      on_exit(qid)
    end
    return
  end

  self.pool:add(job, buf)
end

return ChatHandler
