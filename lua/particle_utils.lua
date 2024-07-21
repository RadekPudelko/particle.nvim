local log = require("log")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")
local Constants = require("constants")

local M = {}


-- TODO: stop searching early if .git found?
-- TODO: unit test this
function M.get_project_type(path)
  local match = string.match(path, "deviceOS/%d+%.%d+%.%d+")
  if match ~= nil then
    -- TODO fix this trash
    local root = vim.fn.fnamemodify(path, ":h")
    local goodRoot = root
    while true do
      match = string.match(root, "deviceOS/%d+%.%d+%.%d+")
      if match ~= nil then
        goodRoot = root
        root = vim.fn.fnamemodify(root, ":h")
      else
        return M.PROJECT_DEVICE_OS, goodRoot
      end
    end
  end

  local results = vim.fs.find({Constants.SettingsFile, type = "file", upward=true})
  if #results == 0 then
    results = vim.fs.find({Constants.PropertiesFile, type = "file", upward=true})
  end

  if #results ~= 0 then
    -- Get dir of project root file
    local root = vim.fs.dirname(results[1])
    return M.PROJECT_LOCAL, root
  end

  return nil, nil
end

-- Project root for saving settings file to
function M.find_project_root()
  local _, root = M.get_project_type(vim.fn.getcwd())
  if root ~= nil then
    return root
  end
  root = vim.fs.root(0, {'.git', 'project.properties'})
  if root ~= nil then
    return root
  end
  return vim.fn.getcwd()
end

function M.LoadSettings()
  local settings_path = settings.find()

  if settings_path == nil then
    log:info("No settings file found in %s", vim.fn.getcwd())
    return nil
  end

  log:info("Loading settings from %s", settings_path)
  -- TODO: Validate all settings json fields are present/valid
  local err = settings.load(settings_path)
  if err ~= nil then
    log:info("Error in loading settings from %s, err=%s", settings_path, err)
    return
  end
  Compile.setup_cc_json_dir()

  env.setup_env(vim.fs.dirname(settings_path))
  return settings_path
end

return M
