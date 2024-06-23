local pft = require("plenary.filetype")

local M = {}

--- Trim leading whitespace and tabs from a string.
--@param str string # The input string to be trimmed.
M.trim = function(str)
  return str:gsub("^[\t ]+", ""):gsub("\n[\t ]+", "\n")
end

---@param fn function # function to wrap so it only gets called once
M.once = function(fn)
  local once = false
  return function(...)
    if once then
      return
    end
    once = true
    fn(...)
  end
end

---@param buf number
---@return string, string
function M.get_buffer_content_as_string(buf, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)

  local min_indent = nil
  local use_tabs = false
  -- measure minimal common indentation for lines with content
  for i, line in ipairs(lines) do
    lines[i] = line
    -- skip whitespace only lines
    if not line:match("^%s*$") then
      local indent = line:match("^%s*")
      -- contains tabs
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
  local prefix = string.rep(use_tabs and "\t" or " ", min_indent)

  for i, line in ipairs(lines) do
    lines[i] = line:sub(min_indent + 1)
  end

  local selection = table.concat(lines, "\n")

  return selection, prefix
end

---@param keys string # string of keystrokes
---@param mode string # string of vim mode ('n', 'i', 'c', etc.), default is 'n'
M.feedkeys = function(keys, mode)
  mode = mode or "n"
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(keys, mode, true)
end

---@param buffers table # table of buffers
---@param mode table | string # mode(s) to set keymap for
---@param key string # shortcut key
---@param callback function | string # callback or string to set keymap
---@param desc string | nil # optional description for keymap
M.set_keymap = function(buffers, mode, key, callback, desc)
  for _, buf in ipairs(buffers) do
    vim.keymap.set(mode, key, callback, {
      noremap = true,
      silent = true,
      nowait = true,
      buffer = buf,
      desc = desc,
    })
  end
end

---@param events string | table # events to listen to
---@param buffers table | nil # buffers to listen to (nil for all buffers)
---@param callback function # callback to call
---@param gid number # augroup id
M.autocmd = function(events, buffers, callback, gid)
  if buffers then
    for _, buf in ipairs(buffers) do
      vim.api.nvim_create_autocmd(events, {
        group = gid,
        buffer = buf,
        callback = vim.schedule_wrap(callback),
      })
    end
  else
    vim.api.nvim_create_autocmd(events, {
      group = gid,
      callback = vim.schedule_wrap(callback),
    })
  end
end

---@param file_name string # name of the file for which to delete buffers
M.delete_buffer = function(file_name)
  -- iterate over buffer list and close all buffers with the same name
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == file_name then
      vim.api.nvim_buf_delete(b, { force = true })
    end
  end
end

---@return string # returns unique uuid
M.uuid = function()
  local random = math.random
  local template = "xxxxxxxx_xxxx_4xxx_yxxx_xxxxxxxxxxxx"
  local result = string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
    return string.format("%x", v)
  end)
  return result
end

---@param name string # name of the augroup
---@param opts table | nil # options for the augroup
---@return number # returns augroup id
M.create_augroup = function(name, opts)
  return vim.api.nvim_create_augroup(name .. "_" .. M.uuid(), opts or { clear = true })
end

---@param buf number # buffer number
---@return number # returns the first line with content of specified buffer
M.last_content_line = function(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  -- go from end and return number of last nonwhitespace line
  local line = vim.api.nvim_buf_line_count(buf)
  while line > 0 do
    local content = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
    if content:match("%S") then
      return line
    end
    line = line - 1
  end
  return 0
end

---@param line number # line number
---@param buf number # buffer number
---@param win number | nil # window number
M.cursor_to_line = function(line, buf, win)
  -- don't manipulate cursor if user is elsewhere
  if buf ~= vim.api.nvim_get_current_buf() then
    return
  end

  -- check if win is valid
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  -- move cursor to the line
  vim.api.nvim_win_set_cursor(win, { line, 0 })
end

---@param str string # string to check
---@param start string # string to check for
M.starts_with = function(str, start)
  return str:sub(1, #start) == start
end

---@param str string # string to check
---@param ending string # string to check for
M.ends_with = function(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

---@param file_name string # name of the file for which to get buffer
---@return number | nil # buffer number
M.get_buffer = function(file_name)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) then
      if M.ends_with(vim.api.nvim_buf_get_name(b), file_name) then
        return b
      end
    end
  end
  return nil
end

---@param buf number # buffer number
M.undojoin = function(buf)
  if not buf or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local status, result = pcall(vim.cmd.undojoin)
  if not status then
    if result:match("E790") then
      return
    end
    M.error("Error running undojoin: " .. vim.inspect(result))
  end
end

-- returns rendered template with specified key replaced by value
M.template_replace = function(template, key, value)
  if template == nil then
    return nil
  end

  if value == nil then
    return template:gsub(key, "")
  end

  if type(value) == "table" then
    value = table.concat(value, "\n")
  end

  value = value:gsub("%%", "%%%%")
  template = template:gsub(key, value)
  template = template:gsub("%%%%", "%%")
  return template
end

---@param template string | nil # template string
---@param key_value_pairs table # table with key value pairs
---@return string | nil # returns rendered template with keys replaced by values from key_value_pairs
M.template_render_from_list = function(template, key_value_pairs)
  if template == nil then
    return nil
  end

  for key, value in pairs(key_value_pairs) do
    template = M.template_replace(template, key, value)
  end

  return template
end

M.template_render = function(template, command, selection, filetype, filename, filecontent, linestart, lineend)
  local key_value_pairs = {
    ["{{command}}"] = command,
    ["{{selection}}"] = selection,
    ["{{filetype}}"] = filetype,
    ["{{filename}}"] = filename,
    ["{{filecontent}}"] = filecontent,
    ["{{linestart}}"] = tostring(linestart),
    ["{{lineend}}"] = tostring(lineend),
  }
  return M.template_render_from_list(template, key_value_pairs)
end

---@param messages table
---@param model string | table | nil
---@param default_model string | table
M.prepare_payload = function(messages, model, default_model)
  model = model or default_model
  local model_req = {
    messages = messages,
    stream = true,
  }

  if type(model) == "string" then
    model_req.model = model
    return model_req
  end

  -- else insert the agent parameters
  for k, v in pairs(model) do
    if k == "temperature" then
      model_req[k] = math.max(0, math.min(2, v or 1))
    elseif k == "top_p" then
      model_req[k] = math.max(0, math.min(1, v or 1))
    else
      if type(v) == "table" then
        model_req[k] = v
        for pk, pv in pairs(v) do
          model_req[k][pk] = pv
        end
      else
        model_req[k] = v
      end
    end
  end

  return model_req
end

---@param buf number # buffer number
---@param file_name string # name of the file
---@param chat_dir string # directory path for chat files
---@return boolean # returns true if file is a chat file
M.is_chat = function(buf, file_name, chat_dir)
  if not M.starts_with(file_name, chat_dir) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines < 4 then
    return false
  end

  if not lines[1]:match("^# ") then
    return false
  end

  if not (lines[3]:match("^- file: ") or lines[4]:match("^- file: ")) then
    return false
  end
  return true
end

---@param params table # table with command args
---@param origin_buf number # selection origin buffer
---@param target_buf number # selection target buffer
M.append_selection = function(params, origin_buf, target_buf, template_selection)
  -- prepare selection
  local lines = vim.api.nvim_buf_get_lines(origin_buf, params.line1 - 1, params.line2, false)
  local selection = table.concat(lines, "\n")
  local filecontent = M.get_buffer_content_as_string(origin_buf, 0, -1)
  if selection ~= "" then
    local filetype = pft.detect(vim.api.nvim_buf_get_name(origin_buf))
    local fname = vim.api.nvim_buf_get_name(origin_buf)
    local rendered =
      M.template_render(template_selection, "", selection, filetype, fname, filecontent, params.line1, params.line2)
    if rendered then
      selection = rendered
    end
  end

  -- delete whitespace lines at the end of the file
  local last_content_line = M.last_content_line(target_buf)
  vim.api.nvim_buf_set_lines(target_buf, last_content_line, -1, false, {})

  -- insert selection lines
  lines = vim.split("\n" .. selection, "\n")
  vim.api.nvim_buf_set_lines(target_buf, last_content_line, -1, false, lines)
end

return M
