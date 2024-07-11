-- check vscode extension version
-- curl -sS -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery
---- with asset urls
-- curl -sS -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 514}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery

-- To download particle vscode extension
-- curl -sS https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage -o particle.tar.gz

local log = require("log")
local Constants = require("constants")
local utils = require("utils")

local M = {}

-- local manifest

local function loadParticleManifest(path)
  local file, err = io.open(path, "r")
  if not file then
    log:warn("Failed to open manifest file=%s err=%s", path, err)
    return nil
  end

  local txt = file:read("*a")
  file:close()

  return vim.json.decode(txt)
end


function M.getPlatforms(manifest)
  local platforms = {}
  for i = 1, #manifest["platforms"] do
    local id = manifest["platforms"][i]["id"]
    local name = manifest["platforms"][i]["name"]
    platforms[id] = name
    platforms[name] = id
  end
  return platforms
end

-- "platforms": [
--     12,
--     13,
--     15,
--     23,
--     25,
--     26
-- ],
-- "firmware": "deviceOS@6.1.0",
-- "compilers": "gcc-arm@10.2.1",
-- "tools": "buildtools@1.1.1",
-- "scripts": "buildscripts@1.15.0",
-- "debuggers": "openocd@0.11.0-particle.4",
function M.getToolchain(manifest, version)
  for i = 1, #manifest["toolchains"] do
    local firmware = manifest["toolchains"][i]["firmware"]
    local desiredVersionString = "deviceOS@" .. version
    if firmware == desiredVersionString then
      return manifest["toolchains"][i]
    end
  end
end

function M.getFirmwareVersions(manifest)
  local versions = {}
  for i = 1, #manifest["toolchains"] do
    local version = manifest["toolchains"][i]["firmware"]
    versions[i] = string.match(version, "@(.*)")
  end
  return versions
end

function M.getFirmwareBinaryUrl(manifest, version)
  -- local url = particleBinariesUrl .. version .. ".tar.gz"
  for i = 1, #manifest["firmware"] do
    local manifestVersion = manifest["firmware"][i]["version"]
    if manifestVersion == version then
      return manifest["firmware"][i]["url"]
    end
  end
  return nil
end

-- Returns true if the platform is valid for the device_os
-- TODO: Add config option to remove this check, ex 5.7.0 can't be compiled for anything, because its missing from manifest.json
function M.is_platform_valid_for_device_os(manifest, device_os, platform)
  local toolchain = M.getToolchain(manifest, device_os)
  if toolchain == nil then
    return false
  end

  local platformMap = M.getPlatforms(manifest)
  for _, platformId in ipairs(toolchain["platforms"]) do
    if platform == platformMap[platformId] then
      return true
    end
  end
  return false
end

-- local function clean()
--   if not utils.exists(Constants.ManifestFile) then
--     if utils.exists(Constants.ManifestVersionFile) then
--       local success, err = os.remove(Constants.ManifestVersionFile)
--       if not success then
--         log:error("Error removing %s, error=%s", Constants.ManifestVersionFile, err)
--       end
--     end
--   elseif not utils.exists(Constants.ManifestVersionFile) then
--     local success, err = os.remove(Constants.ManifestFile)
--     if not success then
--       log:error("Error removing %s, error=%s", Constants.ManifestFile, err)
--     end
--   end
-- end

local function get_current_version_number()
  local manifest_exists = utils.exists(Constants.ManifestFile)
  if not manifest_exists then
    log:debug("Unable to get current manifest version because manifest file doesn't exist")
    return nil
  end
  local manifest_version_exists = utils.exists(Constants.ManifestVersionFile)
  if not manifest_version_exists then
    log:debug("Unable to get current manifest version because manifest version file doesn't exist")
    return nil
  end

  local contents = utils.read_file(Constants.ManifestVersionFile)
  if not utils.isSemanticVersion(contents) then
    log:debug("Unable to get current manifest version because version string %s is not a semantic version", contents)
    return nil
  end
  return utils.parseSemanticVersion(contents)
end

local function get_latest_workbench_info()
    local cmd = {
      "curl",
      "-sS",
      "-X", "POST",
      "-H", "Accept: application/json; charset=utf-8; api-version=7.2-preview.1",
      "-H", "Content-Type: application/json",
      "-d", '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}',
      "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
    }
    local res, out = utils.run(cmd)
    if not res then
      log:warn("Failed to curl manifest version, error: ", out)
      return nil
    else
      return vim.json.decode(out)
    end
end

local function download_workbench()
  local cmd = {
    "curl",
    "-sS",
    "https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage",
    "-o", Constants.WorkbenchDownloadFile
  }
  local res, out = utils.run(cmd)
  if not res then
    return out
  else
    return nil
  end
end

local function extract_workbench()
  utils.ensure_directory(Constants.WorkbenchExtractDir)
  local cmd = {
    'tar',
    '-xf', Constants.WorkbenchDownloadFile,
    '-C', Constants.WorkbenchExtractDir,
    '--strip-components', 1
  }
  local res, out = utils.run(cmd)
  if not res then
    return out
  else
    local success, err = os.remove(Constants.WorkbenchDownloadFile)
    if not success then
      log:error("Error removing %s, error=%s", Constants.WorkbenchDownloadFile, err)
    end
    return nil
  end
end

local function find_manifest_json(search_dir)
  local results = vim.fs.find({"manifest.json", type = "file", path = search_dir})

  if #results == 0 then
    log:error("Failed to find manifest.json in %s", search_dir)
    return nil
  end

  return results[1]
end

local function finalize_manifest(manifest_path, version_string)
  if utils.exists(Constants.ManifestVersionFile) then
    local success, err = os.remove(Constants.ManifestVersionFile)
    if not success then
      log:error("Error removing %s, error=%s", Constants.ManifestVersionFile, err)
    end
  end

  if utils.exists(Constants.ManifestFile) then
    local success, err = os.remove(Constants.ManifestFile)
    if not success then
      log:error("Error removing %s, error=%s", Constants.ManifestFile, err)
    end
  end

  local success, err = os.rename(manifest_path, Constants.ManifestFile)
  if not success then
    log:error("Error moving %s to %s, error=%s", manifest_path, Constants.ManifestFile, err)
  end

  -- if utils.exists(Constants.WorkbenchExtractDir) then
  if utils.exists(Constants.WorkbenchExtractDir) then
    success, err = vim.fn.delete(Constants.WorkbenchExtractDir, "rf")
    if success ~= 0 then
      log:error("Error removing %s, error=%s", Constants.WorkbenchExtractDir, err)
    end
  end

  local file
  file, err = io.open(Constants.ManifestVersionFile, "w")
  if not file then
    log:error("Error opening file=%s, err=%s", Constants.ManifestVersionFile, err)
  end
  file:write(version_string)
  file:close()
end

function M.setup()
  local current_version = get_current_version_number()
  local workbench_json = get_latest_workbench_info()
  if workbench_json == nil then
    if current_version == nil then
      log:error("Unable to load manifest file")
      return
    end
    -- Fallback to local manifset file
    return loadParticleManifest(Constants.ManifestFile)
  end

  -- TODO: Choose the latest
  -- print(vim.inspect(workbench_json))
  local versions = workbench_json["results"][1]["extensions"][1]["versions"][1]
  if #versions > 1 then
    log:debug("There are %d particle workbench versions available", #versions)
  end

  local latest_version_string = versions["version"]
  -- TODO: download workbench if current fails to load?
  if not utils.isSemanticVersion(latest_version_string) then
    log:error("Latest manifest version string is not a semantic version", latest_version_string)
    return loadParticleManifest(Constants.ManifestFile)
  end

  local latest_version = utils.parseSemanticVersion(latest_version_string)
  if current_version and utils.compare_semantic_verions(current_version, latest_version) ~= 1 then
      return loadParticleManifest(Constants.ManifestFile)
  end

  local err = download_workbench()
  if err ~= nil then
    log:error("Failed to download workbench, err=%s", err)
    -- Fallback to local manifset file
    return loadParticleManifest(Constants.ManifestFile)
  end

  err = extract_workbench()
  if err ~= nil then
    log:error("Failed to extract workbench, err=%s", err)
    -- Fallback to local manifset file
    return loadParticleManifest(Constants.ManifestFile)
  end

  local manifest_path = find_manifest_json(Constants.WorkbenchExtractDir)
  if manifest_path == nil then
    -- Fallback to local manifset file
    return loadParticleManifest(Constants.ManifestFile)
  end

  finalize_manifest(manifest_path, latest_version_string)
  return loadParticleManifest(Constants.ManifestFile)
end

return M

