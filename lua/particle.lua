local utils = require "utils"
local manifest = require "manifest"
local firmware = require "firmware"
local tc = require "toolchain"
local ui = require "ui"
local api = vim.api
local buf, win

-- Mason makes an additional header array above installed when updating


-- Particle debug mode

-- 1 way to get versions
--https://api.particle.io/v1/device-os/versions?access_token=

-- A few places to pull particle platforms from
-- toolchain modules contents
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

local CC_PATH = "~/.particle/toolchains/gcc-arm/10.2.1/bin/arm-none-eabi-gcc"
local toolchainFolder = "./toolchains/"

-- local toolchainFolder = "~/.particle/toolchains/"

local particleBinariesUrl = "https://binaries.particle.io/device-os/"
-- line in the buffer where data is loaded, along with top of what user can reach
local cursorStart = 3

--0=not loaded, 1=versions buffer view, 2=version description buffer view
local state = 0;

--table of device os tags
local isInstalled = {}
local versions_loaded = false

local selectedVersion

-- Contents of Particle's manifest json file
local versions = {}
local platforms = {}

local job_id = 0
local startTime

local namespace

local nodes = {}

-- These get loaded with the project.properties and particle.nvim.json paths if they
-- exist, otherwise they are falsy
local particlePropertiesPath
local particleSettingsPath

local function getNodeAtCursor()
    return vim.fn.getcurpos()[2] - cursorStart + 1
end

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

local function loadInitialView()
    api.nvim_buf_set_option(buf, 'modifiable', true)
    local lines = {}
    -- Are we in a particle project
    if particlePropertiesPath then
        if particleSettingsPath then
            lines = {"particle project with particle.nvim.json"}
                local file = io.open(particleSettingsPath, "r")
                if not file then
                    lines = {"Unable to load particle.nvim.json"}
                end
                local settings = file:read("*a")
                file:close()
                -- TODO: Set up some sort of test or checks here to make sure the file format is as
                -- we expect it to be

                local json = vim.json.decode(settings)
                lines = {
                    "plartform: " .. json["platform"],
                    "firmware version: " .. json["firmware_version"],
                }
                -- local toolchainPlatformIds = json["toolchains"][1]["platforms"]
                -- utils.printTable(lines)


        else
            lines = {"particle project without particle.nvim.json"}
        end
    else
        lines = {"no project.properties found"}
    end

    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    -- api.nvim_buf_add_highlight(buf, -1, 'particleSubHeader', 1, 0, -1)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 1
end

local function updateView()
    api.nvim_buf_set_option(buf, 'modifiable', true)

    isInstalled = tc.isInstalled(versions)
    nodes = {}

    local node = ui.Node("## Installed", "na")
    table.insert(nodes, node)
    for i=1, #versions do
        if(isInstalled[versions[i]]) then
            node = ui.Node(versions[i], "deviceOSVersion")
            table.insert(nodes, node)
        end
    end

    node = ui.Node("", "na")
    table.insert(nodes, node)
    node = ui.Node("## Available", "na")
    table.insert(nodes, node)

    local majors = {}
    for i=1, #versions do
        if(not isInstalled[versions[i]]) then
            local major = utils.parseSemanticVersion(versions[i])["major"]
            if not majors[major] then
                majors[major] = 1
                node = ui.Node(major .. ".X.X", "deviceOSBranch")
                table.insert(nodes, node)
            end
        end
    end

    local lines = ui.renderNodes(nodes)

    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    -- api.nvim_buf_add_highlight(buf, -1, 'particleSubHeader', 1, 0, -1)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 2
end

local function restorePreviousView()
    api.nvim_buf_set_option(buf, 'modifiable', true)
    local lines = ui.renderNodes(nodes)
    api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    state = 2
end


local function handleCR()
    if state == 1 then
        -- Create Particle project
        if not particlePropertiesPath then
            return
        end
        -- Create Particle settings json

    end

    if state ~= 2 then return end
    local nodeIndex = getNodeAtCursor()

    -- utils.printTable(nodes)
    local node = nodes[nodeIndex]
    api.nvim_buf_set_option(buf, 'modifiable', true)
    if node["type"] == "deviceOSVersion" or node["type"] == "deviceOSBranchVersion" then
        -- Handle #.#.# lines (get changelog)
        local changelog = firmware.getDeviceOSChanges(node["line"])
        api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, vim.split(changelog, '\n'))
        state = 3
    elseif node["type"] == "deviceOSBranch" then
        -- Handle #.X.X lines (expand/collapse)
        if(node["collapsed"]) then
            node["collapsed"] = false
            local major = string.match(node["line"], "(%d+)%.X.X")
            local branch = tc.getDeviceOSBranch(versions, major)
            for i = #branch, 1, -1 do
                if not isInstalled[branch[i]] then
                    local branchNode = ui.Node(branch[i], "deviceOSBranchVersion")
                    table.insert(nodes, nodeIndex + 1, branchNode)
                end
            end
        else
            node["collapsed"] = true
            -- Iterate from start of branch upto last node or first non branch node
            for i = nodeIndex + 1, #nodes do
                if nodes[nodeIndex + 1].type ~= "deviceOSBranchVersion" then
                    break
                end
                table.remove(nodes, nodeIndex + 1)
            end
        end
        local lines = ui.renderNodes(nodes)
        api.nvim_buf_set_lines(buf, cursorStart - 1, -1, false, lines)
    end

    api.nvim_buf_set_option(buf, 'modifiable', false)

end

local function createDiagnostic(line, message)
    return {
        source = 'particle.nvim',
        code = '0',
        lnum = line - 1,
        end_lnum = line - 1,
        col = 0,
        end_col = 0,
        severity = vim.diagnostic.severity.INFO,
        message = message
    }
end

-- May need to determine what the contents will be called by string building
-- or use tar command to rename the top level contents during decompression
-- TODO: Probably convert this to somesort of job that runs a call back to update the main view at the end of installation
local function installRelease()
    if state ~= 2 then return end

    local line = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(line)

    -- Ignore lines that do not have a version (blank or header)
    if not utils.isSemanticVersion(version) then return end

    local index = 0
    for i = 1, #versions do
       if version == versions[i] then
           index = i
           break
       end
    end
    if index == 0 then -- Should never happen
        print("Unable to find " .. version)
        return
    end
    if isInstalled[version] then return end

    local url = manifest.getFirmwareBinaryUrl(version)
    if not url then
        print("Failed to find binary url for version " .. version)
        return
    end

    -- TODO: Decide what to do when there is a error, show it somehow?
    -- This will download and extract the device os
    local thread = coroutine.create(function()
        local thread = coroutine.running()
        local progress = createDiagnostic(line, "Downloading " .. version)
        vim.diagnostic.show(namespace, buf, {progress});

        -- compressed device os binary downloaded here
        local tarfile = toolchainFolder .. version .. ".tar.gz"
        -- Device os extracted here (folder)
        local contents = toolchainFolder .. version

        local command = {'curl', '-o', tarfile, url}
        local jobId = vim.fn.jobstart(command, {
            on_exit = function(_, code)
                if code ~= 0 then
                    local cmd = table.concat(command, " ")
                    print("Command " .. cmd .. " exited with code " .. code)
                    return
                end
                coroutine.resume(thread)
            end,
        })

        if jobId < 0 then
            print("Failed to start job")
            return
        end
        coroutine.yield()

        if not utils.exists(tarfile) then
            print("Failed to download file from url: " .. url)
            return
        end

        progress = createDiagnostic(line, "Installing " .. version)
        vim.diagnostic.show(namespace, buf, {progress});

        if not utils.run({'mkdir', contents}) then return end

        command = {'tar', '-xf', tarfile, '-C', contents, '--strip-components', 1}
        jobId = vim.fn.jobstart(command, {
            on_exit = function(_, code)
                if code ~= 0 then
                    local cmd = table.concat(command, " ")
                    print("Command " .. cmd .. " exited with code " .. code)
                    return
                end
                coroutine.resume(thread)
            end,
        })

        if jobId < 0 then
            print("Failed to start job")
            return
        end

        coroutine.yield()
        if not utils.run({'rm', tarfile}) then return end
        vim.diagnostic.hide(namespace, buf)
        updateView()
    end)
    coroutine.resume(thread)
end

local function uninstallRelease()
    if state ~= 2 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)

    -- Ignore lines that do not have a version (blank or header)
    if not utils.isSemanticVersion(version) then return end

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

    if not isInstalled[version] then
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
        isInstalled[version] = false
        updateView()
    else
        -- print("Failed to remove " .. file)
    end
end

local function deviceOSView()
    if state ~= 2 then return end

    local curLineNum = vim.fn.getcurpos()[2];
    local version = vim.fn.getline(curLineNum)

    -- Ignore lines that do not have a version (blank or header)
    if not utils.isSemanticVersion(version) then return end

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

    if not isInstalled[version] then return end

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

local function diagnosticTest()
    local curLineNum = vim.fn.getcurpos()[2];
    local progress = {
        source = 'your_source_name',  -- Replace with your source name
        code = 'your_error_code',     -- Replace with your error code
        lnum = curLineNum - 1,
        end_lnum = curLineNum - 1,
        col = 0,
        end_col = 0,
        -- range = {start = {line = curLineNum - 1, character = 0}, ["end"] = {line = curLineNum - 1, character = 0}},
        severity = vim.diagnostic.severity.HINT, -- Or vim.diagnostic.severity.WARN, vim.diagnostic.severity.INFO
        message = "Your diagnostic message here",  -- Replace with your message
    }

    vim.diagnostic.show(namespace, buf, {progress});

    -- vim.diagnostic.set(namespace, buf, {progress})
    -- vim.tbl_map(function(diagnostic)
    --     return {
    --         lnum = diagnostic.line - 1,
    --         col = 0,
    --         message = diagnostic.message,
    --         severity = diagnostic.severity,
    --         source = diagnostic.source,
    --     }
    -- end, {progress}),
    -- {
    --     signs = false,
    -- })
end

local function setMappings()
    local mappings = {
        ['<cr>'] = 'handleCR()',

        o = 'restorePreviousView()',
        q = 'closeWindow()',
        k = 'moveCursor()',
        i = 'installRelease()',
        X = 'uninstallRelease()',
        c = 'deviceOSView()',
        m = 'deviceOSCompile()',
        d = 'diagnosticTest()'
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"particle".'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
        })
    end

    -- these are currently restricting what can be done in the buffer, no gg for instance
    -- local other_chars = {
    --       'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
    --     }
    --     for k,v in ipairs(other_chars) do
    --       api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    --       api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    --       api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
    --     end
end

local function setup()
    namespace = api.nvim_create_namespace("particle.nvim")
    manifest.setup()
    platforms = manifest.getPlatforms()
    versions = manifest.getFirmwareVersions()
    firmware.setup(toolchainFolder)

    particlePropertiesPath = utils.findFile("project.properties")
    particleSettingsPath = utils.findFile("particle.nvim.json")

    -- vim.diagnostic.config({signs = false})
    vim.diagnostic.config({
        virtual_text = {
            severity = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
        },
        right_align = false,
        underline = false,
        signs = false,
        virtual_lines = false,
    }, namespace)
end

local function particle()
    if state ~= 0 then return end
    openWindow()
    setup()
    setMappings()
    loadInitialView()
    -- updateView()
    api.nvim_win_set_cursor(win, {cursorStart, 0})
end

return {
    particle = particle,
    loadInitialView = loadInitialView,
    updateView = updateView,
    restorePreviousView = restorePreviousView,
    moveCursor = moveCursor,
    handleCR = handleCR,
    closeWindow = closeWindow,
    installRelease = installRelease,
    uninstallRelease = uninstallRelease,
    deviceOSView = deviceOSView,
    deviceOSCompile = deviceOSCompile,
    diagnosticTest = diagnosticTest
}

