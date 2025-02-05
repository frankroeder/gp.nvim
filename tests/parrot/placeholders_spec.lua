local Placeholders = require("parrot.Placeholders")

describe("Placeholders", function()
  local placeholders

  before_each(function()
    -- Create a default Placeholders object before each test
    placeholders = Placeholders:new(
      "Hello {{command}}, you selected {{selection}} in file {{filename}} with content {{filecontent}}", -- template
      "doSomething", -- command
      "some text", -- selection
      "lua", -- filetype
      "myfile.lua", -- filename
      "print('Hello World')", -- filecontent
      "file1_content\nfile2_content" -- multifilecontent
    )
  end)

  describe(":new", function()
    it("should correctly initialize the Placeholders object", function()
      local p = Placeholders:new(
        "Template: {{command}}",
        "myCommand",
        "mySelection",
        "python",
        "example.py",
        "print('example')",
        "file1_content\nfile2_content"
      )
      assert.are.equal("Template: {{command}}", p.template)
      assert.are.equal("myCommand", p.command)
      assert.are.equal("mySelection", p.selection)
      assert.are.equal("python", p.filetype)
      assert.are.equal("example.py", p.filename)
      assert.are.equal("print('example')", p.filecontent)
      assert.are.equal("file1_content\nfile2_content", p.multifilecontent)
    end)
  end)

  describe(":template_replace", function()
    it("should replace key with value in template", function()
      local template = "Hello {{name}}!"
      local result = placeholders:template_replace(template, "{{name}}", "World")
      assert.are.equal("Hello World!", result)
    end)

    it("should remove the placeholder if value is nil", function()
      local template = "Hello {{name}}!"
      local result = placeholders:template_replace(template, "{{name}}", nil)
      assert.are.equal("Hello !", result)
    end)

    it("should handle table values by concatenating them with newlines", function()
      local template = "Items: {{items}}"
      local result = placeholders:template_replace(template, "{{items}}", { "apple", "banana", "cherry" })
      assert.are.equal("Items: apple\nbanana\ncherry", result)
    end)

    it("should return nil if template is nil", function()
      local result = placeholders:template_replace(nil, "{{name}}", "World")
      assert.is_nil(result)
    end)
  end)

  describe(":render_from_list", function()
    it("should replace multiple placeholders from a table of key-value pairs", function()
      local template = "Command: {{command}}, Selection: {{selection}}, Filetype: {{filetype}}"
      local key_value_pairs = {
        ["{{command}}"] = "editFile",
        ["{{selection}}"] = "highlighted text",
        ["{{filetype}}"] = "lua",
      }
      local result = Placeholders:new():render_from_list(template, key_value_pairs)
      assert.are.equal("Command: editFile, Selection: highlighted text, Filetype: lua", result)
    end)

    it("should handle a nil template by returning nil", function()
      local result = placeholders:render_from_list(nil, { ["{{command}}"] = "test" })
      assert.is_nil(result)
    end)
  end)

  describe(":return_render", function()
    it("should render using the object's template and fields", function()
      -- By default, placeholders = Placeholders:new("Hello {{command}}, you selected {{selection}} in file {{filename}}...")
      local result = placeholders:return_render()
      local expected = "Hello doSomething, you selected some text in file myfile.lua with content print('Hello World')"
      assert.are.equal(expected, result)
    end)

    it("should replace all placeholders including multifilecontent if used in the template", function()
      -- Let's give a new template that includes multifilecontent
      placeholders.template = "Cmd: {{command}}, Multiline: {{multifilecontent}}"

      local result = placeholders:return_render()
      local expected = "Cmd: doSomething, Multiline: file1_content\nfile2_content"
      assert.are.equal(expected, result)
    end)
  end)

  describe("should replace the nested placeholders", function()
    it("should correctly initialize the Placeholders object", function()
      local template = [[
The filename is {{filename}}.
The selected code is:
```{{filetype}}
{{selection}}
```

User command:
{{command}}]]

      local command = [[
Here is the full file content:
```{{filetype}}
{{filecontent}}
```]]
      local selection = [[
def main():
  print("Hello World!")]]
      local filecontent = [[
def main():
  print("Hello World!")

if __name__ == "__main__":
  main()]]
      local plh = Placeholders:new(template, command, selection, "python", "example.py", filecontent, "")

      local result = plh:return_render()
      local expected = [[
The filename is example.py.
The selected code is:
```python
def main():
  print("Hello World!")
```

User command:
Here is the full file content:
```python
def main():
  print("Hello World!")

if __name__ == "__main__":
  main()
```]]
      assert.are.equal(expected, result)
    end)
  end)
end)
