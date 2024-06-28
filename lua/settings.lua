local utils = require "utils"

local M = {}

local settingsPath = ".particle.nvim.json"

function M.exists()
  local path = utils.findFile(settingsPath)
  return path ~= nil
end

function M.save(config)
    -- config = {deviceOS = "4.2.0", platform = "bsom"}
    local contents = vim.json.encode(config)
    local file = io.open(settingsPath, "w")
    if not file then
        print("Failed to open settings file, err: " .. tostring(file))
        return
    end
    file:write(contents)
    file:close()
end

function M.load()
  -- local path = utils.findFile(settingsPath)
  -- if not path then
  --   print("Settings not found")
  --   return nil
  -- end
  local contents = utils.readfile(settingsPath)
  if not contents then return end
  -- print(contents)
  return vim.json.decode(contents)
end

-- TODO: these defaults need to be generated according to whats installed locally or blank
function M.default()
  local settings = {
    ["device_os"] = "6.1.0",
    ["platform"] = "bsom",
    ["compiler"] = "10.2.1",
    ["scripts"] = "1.15.0"
  }
  return settings
end

-- local function loadProjectJson()
--   local path = utils.findFile(settingsPath)
--   if not path then
--     return nil, settingsPath .. " not found"
--   end
--
--   local file = io.open(path, "r")
--   if not file then
--     return nil, "Unable to read " .. settingsPath
--   end
--
--   local contents = file:read("*a")
--   file:close()
--   -- TODO: Set up some sort of test or checks here to make sure the file format is as
--   -- we expect it to be
--   local json = vim.json.decode(contents)
--   return json, nil
-- end

-- local function saveProjectJson(settings)
--   local json = vim.json.encode(settings)
--   vim.fn.writefile({json}, settingsPath)
-- end

return M

-- lua require("settings").save()
