local ui = require("parrot.ui")

describe("ui", function()
  describe("create_popup", function()
    it("should create a popup window", function()
      local buf, win, close, resize = ui.create_popup(nil, "Test Popup", function()
        return 50, 10, 5, 10
      end)
      assert.is_not_nil(buf)
      assert.is_not_nil(win)
      assert.is_function(close)
      assert.is_function(resize)
      close()
    end)
  end)

  describe("Target", function()
    it("should return correct type for enew", function()
      local result = ui.Target.enew("markdown")
      assert.are.same({ type = 4, filetype = "markdown" }, result)
    end)

    it("should return correct type for new", function()
      local result = ui.Target.new("python")
      assert.are.same({ type = 5, filetype = "python" }, result)
    end)

    it("should return correct type for vnew", function()
      local result = ui.Target.vnew("javascript")
      assert.are.same({ type = 6, filetype = "javascript" }, result)
    end)

    it("should return correct type for tabnew", function()
      local result = ui.Target.tabnew("html")
      assert.are.same({ type = 7, filetype = "html" }, result)
    end)
  end)

  describe("BufTarget", function()
    it("should have correct values", function()
      assert.are.equal(0, ui.BufTarget.current)
      assert.are.equal(1, ui.BufTarget.popup)
      assert.are.equal(2, ui.BufTarget.split)
      assert.are.equal(3, ui.BufTarget.vsplit)
      assert.are.equal(4, ui.BufTarget.tabnew)
    end)
  end)

  -- describe("input", function()
  --   it("should call on_confirm with the input text", function()
  --     local on_confirm_called = false
  --     local test_input = "Test input text"
  --     local on_confirm = function(input)
  --       on_confirm_called = true
  --       assert.are.equal(test_input, input)
  --     end
  --
  --     -- Simulate user input
  --     vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(test_input .. "<C-c>", true, false, true), "i", true)
  --
  --     ui.input({}, on_confirm)
  -- 	print("ON content", on_confirm_called)
  --     assert.is_true(on_confirm_called)
  --   end)
  -- end)
end)
