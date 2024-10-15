local chat_utils = require("parrot.chat_utils")
local ui = require("parrot.ui")
local async = require("plenary.async")

describe("chat_utils", function()
  describe("resolve_buffer_target", function()
    it("should resolve buffer target correctly", function()
      assert.are.equal(ui.BufTarget.popup, chat_utils.resolve_buffer_target({ args = "popup" }))
      assert.are.equal(ui.BufTarget.split, chat_utils.resolve_buffer_target({ args = "split" }))
      assert.are.equal(ui.BufTarget.vsplit, chat_utils.resolve_buffer_target({ args = "vsplit" }))
      assert.are.equal(ui.BufTarget.tabnew, chat_utils.resolve_buffer_target({ args = "tabnew" }))
      assert.are.equal(ui.BufTarget.current, chat_utils.resolve_buffer_target({ args = "" }))
      assert.are.equal(ui.BufTarget.current, chat_utils.resolve_buffer_target({}))
      assert.are.equal(ui.BufTarget.current, chat_utils.resolve_buffer_target(""))
      assert.are.equal(ui.BufTarget.popup, chat_utils.resolve_buffer_target("popup"))
    end)
  end)
  describe("prepare_markdown_buffer", function()
    it("should set buffer and window options correctly", function()
      async.run(function()
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = 80,
          height = 20,
          row = 5,
          col = 5,
        })

        chat_utils.prepare_markdown_buffer(buf)

        -- Check buffer option
        assert.is_false(vim.api.nvim_buf_get_option(buf, "swapfile"))

        -- Check window options
        assert.is_true(vim.api.nvim_win_get_option(win, "wrap"))
        assert.is_true(vim.api.nvim_win_get_option(win, "linebreak"))

        -- Check if autocmd is set (this is a simplified check)
        local autocmds = vim.api.nvim_get_autocmds({ buffer = buf, event = { "TextChanged", "InsertLeave" } })
        assert.is_true(#autocmds > 0)

        vim.api.nvim_win_close(win, true)
        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end)
  end)
end)
