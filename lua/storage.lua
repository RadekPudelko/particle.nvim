local M = {}

local utils = require "utils"

-- TODO: move all these constants type vars to a constants file, delete this one
M.data_path = vim.fn.stdpath('data') .. "/particle"
M.os_cc_json_path = M.data_path .. "/cc/os"

function M.setup()
  utils.ensure_directory(M.data_path)
  utils.ensure_directory(M.ccjson_path)
end

return M
