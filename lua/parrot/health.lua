local M = {}

function M.check()
  vim.health.start("parrot.nvim checks")

  if vim.F.npcall(require, "fzf-lua") then
    vim.health.ok("require('fzf-lua') succeeded")
  else
    vim.health.info("require('fzf-lua') failed")
  end

  if vim.F.npcall(require, "telescope") then
    vim.health.ok("require('telescope') succeeded")
  else
    vim.health.info("require('telescope') failed")
  end

  if vim.F.npcall(require, "plenary") then
    vim.health.ok("require('plenary') succeeded")
  else
    vim.health.info("require('plenary') failed")
  end

  local ok, parrot = pcall(require, "parrot")
  if not ok then
    vim.health.error("require('parrot') failed")
  else
    vim.health.ok("require('parrot') succeeded")

    if parrot.did_setup then
      vim.health.ok("require('parrot').setup() has been called")
    else
      vim.health.error("require('parrot').setup() has not been called")
    end
  end

  for _, name in ipairs({ "curl", "grep", "rg", "ln" }) do
    if vim.fn.executable(name) == 1 then
      vim.health.ok(("`%s` is installed"):format(name))
    else
      vim.health.warn(("`%s` is not installed"):format(name))
    end
  end
end

return M
