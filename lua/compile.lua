local Constants = require("constants")
-- local Installed = require("installed")
-- local Utils = require("utils")

local utils = require "utils"
local M = {}

function M.get_cc_json_dir(settings)
  return Constants.OSCCJsonDir .. "/" .. settings["device_os"] .. "/" .. settings["platform"] .. "/" .. settings["compiler"]
end

-- Each platform has different compile_commands.json output, and there isn't really
-- a good place to store the output file, so we will store it in vim's storage dir
-- for plugins
function M.get_cc_json(settings)
  return M.get_cc_json_dir(settings) .. "/compile_commands.json"
end

-- Creates the dir for the ccjson file if it does not exist
function M.setup_cc_json_dir(settings)
  utils.ensure_directory(M.get_cc_json_dir(settings))
end

function M.delete_cc_json(settings)
  local path = M.get_cc_json(settings)
  local success, err = os.remove(path)
  if success then
    return true
  else
    print("Error deleting file: " .. err)
    return false
  end
end

return M
