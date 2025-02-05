local file_utils = require("parrot.file_utils")
local async = require("plenary.async")

describe("file_utils", function()
  describe("file_to_table", function()
    it("should read and decode JSON file correctly", function()
      async.run(function()
        local temp_file = vim.fn.tempname()
        local test_data = { key = "value", number = 42 }
        local file = io.open(temp_file, "w")
        file:write(vim.json.encode(test_data))
        file:close()

        local result = file_utils.file_to_table(temp_file)
        assert.are.same(test_data, result)

        os.remove(temp_file)
      end)
    end)

    it("should return nil for non-existent file", function()
      async.run(function()
        local result = file_utils.file_to_table("/non/existent/file.json")
        assert.is_nil(result)
      end)
    end)
  end)

  describe("table_to_file", function()
    it("should write table to JSON file correctly", function()
      async.run(function()
        local temp_file = vim.fn.tempname()
        local test_data = { key = "value", number = 42 }

        file_utils.table_to_file(test_data, temp_file)

        local file = io.open(temp_file, "r")
        local content = file:read("*all")
        file:close()

        local decoded = vim.json.decode(content)
        assert.are.same(test_data, decoded)

        os.remove(temp_file)
      end)
    end)
  end)

  describe("find_git_root", function()
    it("should find git root directory", function()
      async.run(function()
        local current_dir = vim.fn.getcwd()
        local result = file_utils.find_git_root()
        assert.are.equal(current_dir, result)
      end)
    end)
  end)

  -- describe("find_repo_instructions", function()
  --   it("should read .parrot.md file from git root", function()
  --     async.run(function()
  --       local result = file_utils.find_repo_instructions()
  --       assert.are.equal("Test instructions", result)
  --     end)
  --   end)
  -- end)

  -- describe("delete_file", function()
  --   it("should delete file from buffer and filesystem", function()
  --     async.run(function()
  --       local temp_file = vim.fn.tempname()
  --       local file = io.open(temp_file, "w")
  --       file:write("Test content")
  --       file:close()

  --       vim.cmd("edit " .. temp_file)
  --       file_utils.delete_file(temp_file, vim.fn.fnamemodify(temp_file, ":h"))

  --       assert.is_false(vim.fn.filereadable(temp_file) == 1)
  --     end)
  --   end)
  -- end)
end)
