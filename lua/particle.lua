local utils = require "utils"
local api = vim.api
local buf, win

-- check vscode extension version
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 512}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery
---- with asset urls
--curl -X POST -H 'Accept: application/json; charset=utf-8; api-version=7.2-preview.1' -H 'Content-Type: application/json' -d '{"filters": [{"criteria": [{"filterType": 7, "value": "particle.particle-vscode-core"}]}], "flags": 514}' https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery

-- 1 way to get versions
--https://api.particle.io/v1/device-os/versions?access_token=

-- A few places to pull particle platforms from
-- toolchain modules folder
---- probably not this one, since the names dont match up with actual platforms
-- toolchain build/platform.mk
---- akward to parse
-- release title (needs to be lower cased + spaces removed)
---- trustworthy?
-- ~/.vscode/extensions/particle.particle-vscode-core-1.16.10/node_modules/@particle/device-constants/dist/js/constants.json
---- For display names, which can be corresponded to platform
-- toolchain .workbench/manifest.json for ids
-- vscode extension: ~/.vscode/extensions/particle.particle-vscode-core-1.16.10/node_modules/@particle/toolchain-manager/manifest.json
---- contains everything

-- TODO: github tarballs/zipballs do not contain submodules, so need to find a way
-- to download full device os
--- See how particle does it
--- Could use git to do it, git clone, checkout, init submodules 
--- particle uses https://binaries.particle.io/device-os/v5.5.0.tar.gz
--- should compare if there is a difference in compiled binaries if using git vs binaries.particle.io


-- Pull changelog from git curl -L https://raw.githubusercontent.com/particle-iot/device-os/develop/CHANGELOG.md
-- use -I flag to get size info so only update the file when it updates
--
-- get os version from https://api.particle.io/v1/build_targets?

--another spot to get partcile device constants: https://www.npmjs.com/package/@particle/device-constants/v/3.3.0?activeTab=code
-- where the toolchains will be installed
--
-- To download particle vscode extension
-- curl https://particle.gallery.vsassets.io/_apis/public/gallery/publisher/particle/extension/particle-vscode-core/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage -o particle.tar.gz
--
--
-- find the manifestjson file
--find . -name manifest.json  | grep toolchain-manager
--find ~/.vscode/extensions -name manifest.json  | grep toolchain-manager
local vscodePath = "~/.vscode/extensions/"
local particleManifestPath

local CC_PATH = "~/.particle/toolchains/gcc-arm/10.2.1/bin/arm-none-eabi-gcc"
local toolchainFolder = "./toolchains/"
-- local toolchainFolder = "~/.particle/toolchains/"

local particleBinariesUrl = "https://binaries.particle.io/device-os/"
-- line in the buffer where data is loaded, along with top of what user can reach
local cursorStart = 3

--0=not loaded, 1=versions buffer view, 2=version description buffer view
local state = 0;

--table of device os tags
local versions = {}
local isInstalled = {}
local tarballUrls = {}
local versions_loaded = false

local selectedVersion

local platforms = {}

local job_id = 0
local startTime


local function center(str)
    local width = api.nvim_win_get_width(0)
    local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
    return string.rep(' ', shift) .. str
end

local function openWindow()
    print("job running: " .. job_id)
    buf = api.nvim_create_buf(false, true)
    local border_buf = api.nvim_create_buf(false, true)

    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    -- api.nvim_buf_set_option(buf, 'filetype', 'particle')
    api.nvim_buf_set_option(buf, 'filetype', 'markdown')

    local width = api.nvim_get_option("columns")
    local height = api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local border_opts = {
        style = "minimal",
        relative = "editor",
        width = win_width + 2,
        height = win_height + 2,
        row = row - 1,
        col = col - 1
    }

    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col
    }

    local border_lines = { '╔' .. string.rep('═', win_width) .. '╗' }
    local middle_line = '║' .. string.rep(' ', win_width) .. '║'
    for i=1, win_height do
        table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '╚' .. string.rep('═', win_width) .. '╝')
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    local border_win = api.nvim_open_win(border_buf, true, border_opts)
    win = api.nvim_open_win(buf, true, opts)
    api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

    api.nvim_win_set_option(win, 'cursorline', true)

    api.nvim_buf_set_lines(buf, 0, -1, false, { center('Particle.nvim'), '', ''})
    state = 1
    -- api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
end

-- Find the Particle's manifest file from within their toolchain package in the
-- particle workbench core vscode extension
-- Used to load particle platforms, ids, device os versions and more
local function findParticleManifest()
    local result = api.nvim_call_function('systemlist', {
        "find " .. vscodePath .. " -name manifest.json | grep toolchain-manager"
    })
    if #result == 0 then
        print("Failed to find particle manifest")
    elseif #result > 1 then
        print("Found multiple particle manifests")
    end
    particleManifestPath = result[1]
    print("Using particle manifset from " .. result[1])
end

local function updateView()
    api.nvim_buf_set_option(buf, 'modifiable', true)

    -- if not versions_loaded then
    --     local result = api.nvim_call_function('system', {
    --         "curl -Ls https://api.github.com/repos/particle-iot/device-os/tags"
    --     })
    --
    --     -- parse json response if there was one
    --     local json = nil
    --     if #result ~= 0 then
    --         json = vim.json.decode(result)
    --     end
    --
    --     -- Curl failed due to network or no tag results in the curl
    --     -- expecting 30 tags by default
    --     if #result == 0 or json[1] == nil then
    --         versions[1] = 'Failed to curl tags from https://api.github.com/repos/particle-iot/device-os/tags'
    --     else
    --         versions = {}
    --         for i=1, #json do
    --             versions[i] = json[i]["name"]
    --             tarballUrls[i] = json[i]["zipball_url"]
    --         end
    --         versions_loaded = true
    --     end
    -- end


    -- TODO: figure out better check for installation, maybe a file I create?
    for i=1, #versions do
        local file = toolchainFolder .. versions[i]
        -- TODO: figure out possible errs and how to handle
        local exists, err = utils.exists(file)
        -- print("err ".. err)
        isInstalled[i] = exists
    end

    local myLines = {}
    myLines[1] = "## Installed"
    local line = 2
    for i=1, #versions do
        if(isInstalled[i]) then
            myLines[line] = versions[i]
            line = line + 1
        end
    end

    myLines[line] = ""
    line = line + 1

    myLines[line] = "## Available"
    line = line + 1
    for i=1, #versions do
        if(not isInstalled[i]) then
            myLines[line] = versions[i]
            line = line + 1
        end
    end



    -- api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, versions)
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, myLines)

    -- api.nvim_buf_add_highlight(buf, -1, 'particleSubHeader', 1, 0, -1)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 1
end

local function loadPlatforms()
    local file = io.open(particleManifestPath, "r")
    if not file then return end
    local manifestJson = file:read("*a")
    file:close()

    local json = vim.json.decode(manifestJson)
    -- utils.printTable(manifestJson)
    for i = 1, #json["platforms"] do
        local id = json["platforms"][i]["id"]
        platforms[id] = json["platforms"][i]["name"]
    end

    for i = 1, #json["toolchains"] do
        local version = json["toolchains"][i]["firmware"]
        version = string.match(version, "@(.*)")
        versions[i] = version
    end

end

local function loadReleaseBody()
    if state ~= 1 then return end

    api.nvim_buf_set_option(buf, 'modifiable', true)

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)
    if #version == 0 then return end

    local result = api.nvim_call_function('system', {
        "curl -Ls https://api.github.com/repos/particle-iot/device-os/releases/tags/"..version
    })

    local json = vim.json.decode(result)
    local body = json["body"]
    local lines = {}
    for s in body:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    api.nvim_set_option_value('filetype', 'markdown', {['buf']=buf})
    -- api.nvim_set_option_value('startofline', true, {['win']=win})
    -- api.nvim_set_option_value('wrap', true, {['buf']=buf})
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 2
end

-- May need to determine what the folder will be called by string building
-- or use tar command to rename the top level folder during decompression
-- TODO: Probably convert this to somesort of job that runs a call back to update the main view at the end of installation
local function installRelease()
    if state ~= 1 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)

    -- Ignore lines that do not have a version (blank or header)
    if #version == 0 then return end
    if(string.lower(string.sub(version, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    local file = toolchainFolder .. version
    if isInstalled[index] then
        print(version .. " is already installed at " .. file)
        return
    end

    -- local url = tarballUrls[index]

    local url = particleBinariesUrl .. version .. ".tar.gz"
    local tarfile = toolchainFolder .. version .. ".tar.gz"

    local cmd = "wget -cO - " .. url .. " > " .. tarfile
    print(cmd)
    local result = api.nvim_call_function('system', {
        cmd
    })
    -- print(result)

    if not utils.exists(tarfile) then
        print("Failed to download file from url: " .. url)
        return
    end

    -- TODO: check if the downloaded file exists
    result = api.nvim_call_function('system', {
        "mkdir " .. file
    })

    local cmd = "tar -xf " .. tarfile .. " -C " .. file .. " --strip-components 1"
    print(cmd)
    result = api.nvim_call_function('system', {
        cmd
    })

    result = api.nvim_call_function('system', {
        'rm ' .. tarfile
    })

    updateView()
end

local function uninstallRelease()
    if state ~= 1 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)

    -- Ignore lines that do not have a version (blank or header)
    if #version == 0 then return end
    if(string.lower(string.sub(version, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    if not isInstalled[index] then
        print("Not installed")
        return
    end

    local file = toolchainFolder .. version

    local confirmation
    repeat
        confirmation = vim.fn.input("Confirm rm -rf on " .. file .. " (y/n): ")
    until(confirmation == 'y') or (confirmation == 'n')

    -- clear command area
    vim.cmd("echon ' '")

    if(confirmation == 'n') then return end

    local result = api.nvim_call_function('system', {
        "rm -rf " .. file
    })

    if not utils.exists(file) then
        -- print(version .. " was successfully removed")
        isInstalled[index] = false
        updateView()
    else
        -- print("Failed to remove " .. file)
    end
end

local function deviceOSView()
    if state ~= 1 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)

    -- Ignore lines that do not have a version (blank or header)
    if #version == 0 then return end
    if(string.lower(string.sub(version, 1, 1)) ~= 'v') then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end

    if index == 0 then
        -- Should never happen
        print("Unable to find " .. version)
        return
    end

    if not isInstalled[index] then return end

    local toolchainManifest = toolchainFolder .. version .. "/.workbench/manifest.json"
    local file = io.open(toolchainManifest, "r")
    if not file then return end
    local manifestJson = file:read("*a")
    file:close()

    -- TODO: Set up some sort of test or checks here to make sure the file format is as
    -- we expect it to be
    local json = vim.json.decode(manifestJson)
    local toolchainPlatformIds = json["toolchains"][1]["platforms"]

    -- TODO: The line setting is not working correctly
    local myLines = {}
    local line = 1
    myLines[line] = "Device OS: " .. version
    line = line + 1
    myLines[line] = ""
    line = line + 1

    for i=1, #toolchainPlatformIds do
        local id = toolchainPlatformIds[i]
        myLines[line] = platforms[id]
        line = line + 1
    end

    selectedVersion = version

    api.nvim_buf_set_option(buf, 'modifiable', true)
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, myLines)

    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 3

    -- utils.printTable(json["platforms"])
end

-- there is an option to make stdout/err buffered, so that its is handled all at once
local function asyncTest(command, cwd, envVars)
    -- Define job options
end

-- This job will die if neovim is closed, but not if the plugin is closed
local function deviceOSCompile()
    if state ~= 3 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local currentLineText = vim.fn.getline(curLineNum)

    if #currentLineText == 0 then return end

    local isValidPlatform = false
    for id, name in pairs(platforms) do
        if currentLineText == name then
            isValidPlatform = true
            break
        end
    end

    if not isValidPlatform then return end

    local toolchainModules = toolchainFolder .. selectedVersion .. "/modules"
    local command = {"bear", "--", "make", "clean", "all", "-s", "PLATFORM=" .. currentLineText}
    local job_options = {
        cwd = toolchainModules,
        env = {CC=CC_PATH},
        on_exit = function(_, code)
            print("Command exit with code " .. code)
            local endTime = os.time()
            local elapsed = endTime - startTime
            print("Job runtime: " .. elapsed .. " seconds")
        end,
    }

    -- Run the job
    startTime = os.time()
    job_id = vim.fn.jobstart(command, job_options)
    print("job_id: " .. job_id)
end

local function closeWindow()
    api.nvim_win_close(win, true)
    state = 0
end

-- Limit cursor movement to within the version section
local function moveCursor()
    local new_pos = math.max(cursorStart, api.nvim_win_get_cursor(win)[1] - 1)
    api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function setMappings()
    local mappings = {
        ['<cr>'] = 'loadReleaseBody()',

        -- hl are restricting movement in the buffers
        h = 'updateView()',
        l = 'updateView()',
        q = 'closeWindow()',
        k = 'moveCursor()',
        i = 'installRelease()',
        X = 'uninstallRelease()',
        c = 'deviceOSView()',
        m = 'deviceOSCompile()',
        -- a = 'asyncTest()'
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"particle".'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
        })
    end

    -- these are currently restricting what can be done in the buffer, no gg for instance
    -- local other_chars = {
        --   'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
        -- }
        -- for k,v in ipairs(other_chars) do
        --   api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
        --   api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
        --   api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
        -- end
end

local function particle()
    if state ~= 0 then return end
    openWindow()
    findParticleManifest()
    loadPlatforms()
    setMappings()
    updateView()
    api.nvim_win_set_cursor(win, {cursorStart, 0})
end

return {
    particle = particle,
    updateView = updateView,
    moveCursor = moveCursor,
    loadReleaseBody = loadReleaseBody,
    closeWindow = closeWindow,
    installRelease = installRelease,
    uninstallRelease = uninstallRelease,
    deviceOSView = deviceOSView,
    deviceOSCompile = deviceOSCompile,
    asyncTest = asyncTest,
    findParticleManifest = findParticleManifest
}

