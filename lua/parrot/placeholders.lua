---@class Placeholders
---@field template string # The template string
---@field command string # The command
---@field selection string | nil # The selected text
---@field filetype string | nil # The file type
---@field filename string | nil # The file name
---@field filecontent string | nil # The file content
---@field multifilecontent string | nil # The content of multiple files
local Placeholders = {}
Placeholders.__index = Placeholders

---@param template string # The template string
---@param command string # The command
---@param selection string | nil # The selected text
---@param filetype string | nil # The file type
---@param filename string | nil # The file name
---@param filecontent string | nil # The file content
---@param multifilecontent string | nil # The content of multiple files
---@return Placeholders
function Placeholders:new(template, command, selection, filetype, filename, filecontent, multifilecontent)
  local self = setmetatable({}, Placeholders)
  self.template = template
  self.command = command
  self.selection = selection
  self.filetype = filetype
  self.filename = filename
  self.filecontent = filecontent
  self.multifilecontent = multifilecontent
  return self
end

---@return string
function Placeholders:return_render()
  -- First, render any placeholders inside the `command` string
  local rendered_command = self:render_from_list(self.command, {
    ["{{filetype}}"] = self.filetype,
    ["{{filename}}"] = self.filename,
    ["{{filecontent}}"] = self.filecontent,
    ["{{multifilecontent}}"] = self.multifilecontent,
    ["{{selection}}"] = self.selection,
  })

  -- Now inject that fully rendered command into the main template
  local key_value_pairs = {
    ["{{command}}"] = rendered_command,
    ["{{selection}}"] = self.selection,
    ["{{filetype}}"] = self.filetype,
    ["{{filename}}"] = self.filename,
    ["{{filecontent}}"] = self.filecontent,
    ["{{multifilecontent}}"] = self.multifilecontent,
  }

  return self:render_from_list(self.template, key_value_pairs)
end

-- Render a template by replacing all placeholders, including those that may be
-- nested inside other placeholders. We repeat until no further replacements happen
-- or we hit a safety limit.
---@param template string|nil
---@param key_value_pairs table<string, string|table|nil>
---@return string|nil
function Placeholders:render_from_list(template, key_value_pairs)
  if template == nil then
    return nil
  end

  -- Convert any table values to newline-joined strings, and escape '%' properly.
  -- Also allow `nil` to remove placeholders.
  local function expand_once(text)
    for key, value in pairs(key_value_pairs) do
      -- If value is a table, join with newlines:
      if type(value) == "table" then
        value = table.concat(value, "\n")
      end

      -- If nil, remove that placeholder altogether:
      if value == nil then
        text = text:gsub(key, "")
      else
        -- Escape '%' so gsub doesn't interpret them
        local escaped = tostring(value):gsub("%%", "%%%%")
        text = text:gsub(key, escaped)
      end
    end
    return text
  end

  -- Perform repeated expansions until no changes or iteration limit
  local old = nil
  local new = template
  local iteration_count = 0
  local max_iterations = 2 -- avoid infinite loops in pathological cases

  while new ~= old and iteration_count < max_iterations do
    iteration_count = iteration_count + 1
    old = new
    new = expand_once(old)
  end

  return new
end

-- Replace a key in a template string with a given value.
---@param template string # The template string
---@param key string # The key to replace
---@param value string|table # The value to replace the key with
---@return string # The rendered template
function Placeholders:template_replace(template, key, value)
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

return Placeholders
