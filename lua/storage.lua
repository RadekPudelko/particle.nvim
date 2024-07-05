local M = {}

local Utils = require("utils")

-- TODO: move all these constants type vars to a constants file, delete this one
M.data_path = vim.fn.stdpath('data') .. "/particle"
M.os_cc_json_path = M.data_path .. "/cc/os"

function M.setup()
  Utils.ensure_directory(M.data_path)
  Utils.ensure_directory(M.ccjson_path)
end

return M
