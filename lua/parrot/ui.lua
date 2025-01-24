local utils = require("parrot.utils")

local M = {}

M.Target = {
  rewrite = 0, -- for replacing the selection, range or the current line
  append = 1, -- for appending after the selection, range or the current line
  prepend = 2, -- for prepending before the selection, range or the current line
  popup = 3, -- for writing into the popup window

  -- for writing into a new buffer
  ---@param filetype nil | string # nil = same as the original buffer
  ---@return table # a table with type=4 and filetype=filetype
  enew = function(filetype)
    return { type = 4, filetype = filetype }
  end,

  --- for creating a new horizontal split
  ---@param filetype nil | string # nil = same as the original buffer
  ---@return table # a table with type=5 and filetype=filetype
  new = function(filetype)
    return { type = 5, filetype = filetype }
  end,

  --- for creating a new vertical split
  ---@param filetype nil | string # nil = same as the original buffer
  ---@return table # a table with type=6 and filetype=filetype
  vnew = function(filetype)
    return { type = 6, filetype = filetype }
  end,

  --- for creating a new tab
  ---@param filetype nil | string # nil = same as the original buffer
  ---@return table # a table with type=7 and filetype=filetype
  tabnew = function(filetype)
    return { type = 7, filetype = filetype }
  end,
}

M.BufTarget = {
  current = 0, -- current window
  popup = 1, -- popup window
  split = 2, -- split window
  vsplit = 3, -- vsplit window
  tabnew = 4, -- new tab
}

---@param buf number | nil # buffer number
---@param title string # title of the popup
---@param size_func function # size_func(editor_width, editor_height) -> width, height, row, col
---@param opts table # options - gid=nul, on_leave=false, keep_buf=false
---@param style table # style - border="single"
---returns table with buffer, window, close function, resize function
M.create_popup = function(buf, title, size_func, opts, style)
  opts = opts or {}
  style = style or {}
  local border = style.border or "single"

  -- create buffer
  buf = buf or vim.api.nvim_create_buf(not not opts.persist, not opts.persist)

  -- setting to the middle of the editor
  local options = {
    relative = "editor",
    -- dummy values gets resized later
    width = 10,
    height = 10,
    row = 10,
    col = 10,
    style = "minimal",
    border = border,
    title = title,
    title_pos = "center",
  }

  -- open the window and return the buffer
  local win = vim.api.nvim_open_win(buf, true, options)

  local resize = function()
    -- get editor dimensions
    local ew = vim.api.nvim_get_option_value("columns", {})
    local eh = vim.api.nvim_get_option_value("lines", {})

    local w, h, r, c = size_func(ew, eh)

    -- setting to the middle of the editor
    local o = {
      relative = "editor",
      -- half of the editor width
      width = math.floor(w),
      -- half of the editor height
      height = math.floor(h),
      -- center of the editor
      row = math.floor(r),
      -- center of the editor
      col = math.floor(c),
    }
    vim.api.nvim_win_set_config(win, o)
  end

  local pgid = opts.gid or utils.create_augroup("PrtPopup", { clear = true })

  -- cleanup on exit
  local close = (function()
    local called = false
    return function()
      if called then
        return
      end
      called = true
      vim.schedule(function()
        if not opts.gid then
          vim.api.nvim_del_augroup_by_id(pgid)
        end
        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if opts.keep_buf then
          return
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end)
    end
  end)()

  -- resize on vim resize
  utils.autocmd("VimResized", { buf }, resize, pgid)

  -- cleanup on buffer exit
  utils.autocmd({ "BufWipeout", "BufHidden", "BufDelete" }, { buf }, close, pgid)

  -- optional cleanup on buffer leave
  if opts.on_leave then
    -- close when entering non-popup buffer
    utils.autocmd({ "BufEnter" }, nil, function(event)
      local b = event.buf
      if b ~= buf then
        close()
        -- make sure to set current buffer after close
        vim.schedule(vim.schedule_wrap(function()
          vim.api.nvim_set_current_buf(b)
        end))
      end
    end, pgid)
  end

  -- cleanup on escape exit
  if opts.escape then
    utils.set_keymap({ buf }, "n", "<esc>", close, title .. " close on escape")
    utils.set_keymap({ buf }, { "n", "v", "i" }, "<C-c>", close, title .. " close on escape")
  end

  resize()
  return buf, win, close, resize
end

M.input = function(opts, on_confirm)
  vim.validate({
    opts = { opts, "table", true },
    on_confirm = { on_confirm, "function", false },
  })
  opts = (opts and not vim.tbl_isempty(opts)) and opts or vim.empty_dict()

  local prompt = opts.prompt or "Enter text here... "
  local hint = [[confirm with: CTRL-W_q or CTRL-C (all modes) | Esc (normal mode)]]

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Open the buffer in an upper split
  vim.cmd("aboveleft split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Set buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- Add prompt and hint as virtual text
  local ns_id = vim.api.nvim_create_namespace("input_prompt")
  vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
    virt_text = { { prompt .. hint, "Comment" } },
    virt_text_pos = "overlay",
  })

  -- Enter insert mode in next line
  vim.cmd("normal! o")
  vim.cmd("startinsert")
  if opts.default and type(opts.default) == "string" then
    local trimmed_default = utils.trim(opts.default) or ""
    vim.api.nvim_buf_set_lines(0, -2, -1, true, { trimmed_default })
  end

  -- Set up an autocommand to capture buffer content when the window is closed
  vim.api.nvim_create_autocmd({ "WinClosed", "BufLeave" }, {
    buffer = buf,
    callback = function()
      -- Get buffer content
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Delete the buffer
      vim.api.nvim_buf_delete(buf, { force = true })

      on_confirm(content)
      return true
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "<Esc>:q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-c>", ":q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })
end

return M
