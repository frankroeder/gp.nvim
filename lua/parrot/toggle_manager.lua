local logger = require("parrot.logger")

local TOGGLE_KIND = {
  UNKNOWN = 0,
  CHAT = 1,
  POPUP = 2,
  CONTEXT = 3,
}

local ToggleManager = {}
ToggleManager.__index = ToggleManager

function ToggleManager:new()
  return setmetatable({ toggles = {} }, self)
end

function ToggleManager:close(kind)
  local toggle = self.toggles[kind]
  if toggle and vim.api.nvim_win_is_valid(toggle.win) and vim.api.nvim_buf_is_valid(toggle.buf) then
    if #vim.api.nvim_list_wins() > 1 then
      toggle.close()
      self.toggles[kind] = nil
      return true
    else
      logger.warning("Can't close the last window.")
    end
  end
  self.toggles[kind] = nil
  return false
end

function ToggleManager:add(kind, toggle)
  self.toggles[kind] = toggle
end

function ToggleManager:resolve(kind_str)
  kind_str = kind_str:lower()
  local kind_map = {
    chat = TOGGLE_KIND.CHAT,
    popup = TOGGLE_KIND.POPUP,
    context = TOGGLE_KIND.CONTEXT,
  }
  return kind_map[kind_str] or TOGGLE_KIND.UNKNOWN
end

return ToggleManager
