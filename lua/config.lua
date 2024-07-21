local default_config = {
  log = {
    {
      type = "echo",
      level = vim.log.levels.WARN,
    },
    {
      type = "file",
      filename = "particle.log",
      -- level = vim.log.levels.WARN,
      level = vim.log.levels.DEBUG,
    },
  },
}

local M = vim.deepcopy(default_config)

M.setup = function(opts)
  local log = require("log")
  opts = opts or {}
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  log.set_root(log.new({ handlers = M.log }))

end

return M
