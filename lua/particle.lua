local config = require("config")
local log = require("log")
local Utils = require("utils")
local Manifest = require("manifest")
local Compile = require("compile")
local settings = require("settings")
local env = require("env")
local Constants = require("constants")
local Commands = require("overseer_commands")
local particle_utils = require("particle_utils")
local ui = require("ui")
local utils = require("utils")

--TODO: Looks like switch platform doesn't give that new platforms compile-commands-dir when entering device os until
--nvim is reset

local initialized = 0

local M = {}
-- TODO: add way to show user log file location
-- TODO: add way to quickly open log file, like LspLog command

-- TODO: these are duplicated here just for export reasons, figure out how to export
-- from particle_utils directly
M.PROJECT_DEVICE_OS = 1
M.PROJECT_LOCAL= 2

function M.hello()
  return "hello"
end

function M.get_device_os_ccjson_dir()
  if settings == nil then
    return nil
  end
  local cc_dir = Compile.get_cc_json_dir()
  if not vim.fn.isdirectory(cc_dir) then
    return nil
  end
  return cc_dir
end

-- TODO: check if it exists?
function M.get_query_driver()
  if settings == nil then
    return nil
  end
  return settings.get_query_driver()
end

-- TODO: Look into how to export these functions directly
function M.get_project_type(path)
  return particle_utils.get_project_type(path)
end


--TODO: Switching platform should try to do something to fix the compile_commands.json that is
--used by the device os. This can be done by checking if there exists a compile_commands json
--for the specific platform for the device os and relinking it so that it is active. Otherwise, it
--can prompt the user if it would like to compile the device os to create the compile commands.
-- Would also have to prompt on change in devie os. IDK about change in compiler? Could use custom
-- link names in the modules fokder than link in to the device os.
-- This can get messy with multiple projects using hte same device os but different platforms.
-- Maybe could merge the compile commands json file from device os and project
-- Or could have particle.nvim supplu the correct compile commands json as the query driver arg
-- to clangd!!
--TODO: Need to keep track of which compile-comamnds are linked if going with a linked approach, but
--not for a clangd supplied file via --compile-commands-dir=
-- TODO: add a menu for additional CCFLAGs
-- TODO: add way of determining whether compile-os with bear finished so that it can be restarted on boot
-- TODO: A Clean os is not required for all platforms, only for those for which there is a shared command.
-- Its possible to tell which have the same command via platform-ids.mk in deviceOs/build, but that doesn't
-- necessarily tell you if you need to clean
-- Could look at build/target folder?

-- TODO: Could restart LSP after compiling, technically it works fine, but the diagnostics aren't resolved until
-- restart

-- TODO: Take options for window
-- Configuration
-- Auto compile device os
-- logging
--

-- TODO: Setup mappings like is available in Overseer or Telescope
local function create_user_commands()
  vim.api.nvim_create_user_command('Particle', function()
    vim.cmd('lua require("particle").project()')
  end, {
      desc = 'Opens the Particle project menu',
    })
end

function M.setup2(user_config)
  if initialized == 0 then
    initialized = 1
    config.setup(user_config)
    create_user_commands()
    Utils.ensure_directory(Constants.DataDir)
    Utils.ensure_directory(Constants.OSCCJsonDir)
    Utils.ensure_directory(Constants.ManifestDir)

    local err = Manifest.setup()
    if err ~= nil then
      log:error("Failed to load manifest, err=%s", err)
    end

    local project_root = particle_utils.LoadSettings()
    if project_root ~= nil then
      project_root = vim.fs.dirname(project_root)
    else
      project_root = particle_utils.find_project_root()
      log:info("No settings found for project %s", project_root)
      return
    end

    Commands.setup()
  end
end

-- Fallback to local manifset file
local function fallback()
  local thread = coroutine.running()
  vim.schedule(function()
    local err = Manifest.loadParticleManifest(Constants.ManifestFile)
    if err ~= nil then
      log:error("Failed to fallback to local particle manifest, err=%s", err)
    end

    local project_root = particle_utils.LoadSettings()
    if project_root ~= nil then
      project_root = vim.fs.dirname(project_root)
      Commands.setup()
    else
      project_root = particle_utils.find_project_root()
      log:info("No settings found for project %s", project_root)
    end

    coroutine.resume(thread)
  end)
  coroutine.yield()
end

-- Need to scheduled log and schedule fs operations in coroutine
function M.setup(user_config)
  if initialized == 0 then
    initialized = 1
    config.setup(user_config)
    create_user_commands()
    Utils.ensure_directory(Constants.DataDir)
    Utils.ensure_directory(Constants.OSCCJsonDir)
    Utils.ensure_directory(Constants.ManifestDir)
    Utils.ensure_directory(Constants.WorkbenchExtractDir)

    local current_version = Manifest.get_current_version_number()

    local thread = coroutine.create(function()
      local thread = coroutine.running()

      -- Check for new Particle workbench version
      ----------------------------------------------------------------------------------------
      local workbench_json
      local command = {
        "curl",
        "-sS",
        "-X", "POST",
        "-H", "Accept: application/json; charset=utf-8; api-version=7.2-preview.1",
        "-H", "Content-Type: application/json",
        "-d", '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}',
        "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
      }
      vim.system(command, {text=true}, function(obj)
        if obj.code ~= 0 then
          log:swarn("Failed to curl manifest version, code=%d, error=%s", obj.code, obj.stderr)
          log:sdebug("command: %s", table.concat(command, " "))
          return
        else
          workbench_json = vim.json.decode(obj.stdout)
          coroutine.resume(thread)
        end
      end)
      coroutine.yield()

      if workbench_json == nil then
        log:serror("Failed to deserialize workbench json")
        if current_version == nil then
          log:serror("Unable to fallback to local manifest")
          return
        end
        log:serror("New workbench json deserialization failed")
        return fallback()
      end
      log:sdebug("Successfuly curled new manifest version json")

      -- See if the latest version is newer than the current
      ----------------------------------------------------------------------------------------
      -- TODO: Choose the latest
      local versions = workbench_json["results"][1]["extensions"][1]["versions"][1]
      if #versions > 1 then
        log:sdebug("There are %d particle workbench versions available", #versions)
      end

      local latest_version_string = versions["version"]
      -- TODO: download workbench if current fails to load?
      if not utils.isSemanticVersion(latest_version_string) then
        log:serror("Latest manifest version string is not a semantic version", latest_version_string)
        return fallback()
      end

      local latest_version = utils.parseSemanticVersion(latest_version_string)
      if current_version and utils.compare_semantic_verions(current_version, latest_version) ~= 1 then
        log:sdebug("Current manifest version is newer or same as the lastest")
        return fallback()
      end

      -- There is a newer Particle Workbench, available, download it
      ----------------------------------------------------------------------------------------
      command = {
        "curl",
        "-sS",
        "https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage",
        "-o", Constants.WorkbenchDownloadFile
      }
      vim.system(command, {text=true}, function(obj)
        if obj.code ~= 0 then
          log:swarn("Failed to curl latest workbench, code=%d, error=%s", obj.code, obj.stderr)
          log:sdebug("command: %s", table.concat(command, " "))
          return fallback()
        else
          coroutine.resume(thread)
        end
      end)
      coroutine.yield()

      -- Extract the workbench files
      ----------------------------------------------------------------------------------------
      command = {
        'tar',
        '-xf', Constants.WorkbenchDownloadFile,
        '-C', Constants.WorkbenchExtractDir,
        '--strip-components', 1
      }
      vim.system(command, {text=true}, function(obj)
        if obj.code ~= 0 then
          log:serror("Failed to extract workbench, code=%d, error=%s", obj.code, obj.stderr)
          log:sdebug("command: %s", table.concat(command, " "))
          return fallback()
        else
          log:sdebug("Extract workbench success")
          coroutine.resume(thread)
        end
      end)
      coroutine.yield()

      -- Extract the manifest file and clean up
      ----------------------------------------------------------------------------------------
      local manifest_path
      vim.schedule(function()
        -- Shouldn't ever fail, but its also not that big of a deal if we fail to clean up after extraction
        local success, err = os.remove(Constants.WorkbenchDownloadFile)
        if not success then
          log:swarn("Error removing %s, error=%s", Constants.WorkbenchDownloadFile, err)
        end
        manifest_path = Manifest.find_manifest_json(Constants.WorkbenchExtractDir)
        coroutine.resume(thread)
      end)
      coroutine.yield()

      if manifest_path == nil then
        -- Fallback to local manifset file
        log:serror("Failed to find manifest.json in %s", Constants.WorkbenchExtractDir)
        return fallback()
      else
        log:sinfo("Found manifest at %s", manifest_path)
      end
      vim.schedule(function()
        Manifest.finalize_manifest(manifest_path, latest_version_string)
        coroutine.resume(thread)
      end)
      coroutine.yield()

      -- Load the new manifest and finish setup
      ----------------------------------------------------------------------------------------
      vim.schedule(function()
        local err = Manifest.loadParticleManifest(Constants.ManifestFile)
        if err ~= nil then
          log:serror("Failed to load new particle manifest, err=%s", err)
        end

        local project_root = particle_utils.LoadSettings()
        if project_root ~= nil then
          project_root = vim.fs.dirname(project_root)
          log:info("project_root=%s", project_root)
          Commands.setup()
        else
          project_root = particle_utils.find_project_root()
          log:info("No settings found for project %s", project_root)
        end
        coroutine.resume(thread)
      end)
      coroutine.yield()
    end)
    coroutine.resume(thread)
  end
end

function M.project()
  M.setup()
  ui.CreateMainMenu()
end

log:info("Hello from particle.nvim")

return M
