local M = {}

function M.printTable(t)
  local printTable_cache = {}

  local function sub_printTable(t, indent)
    if (printTable_cache[tostring(t)]) then
      print(indent .. "*" .. tostring(t))
    else
      printTable_cache[tostring(t)] = true
      if (type(t) == "table") then
        for pos, val in pairs(t) do
          if (type(val) == "table") then
            print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
            sub_printTable(val, indent .. string.rep(" ", string.len(pos) + 8))
            print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
          elseif (type(val) == "string") then
            print(indent .. "[" .. pos .. '] => "' .. val .. '"')
          else
            print(indent .. "[" .. pos .. "] => " .. tostring(val))
          end
        end
      else
        print(indent .. tostring(t))
      end
    end
  end

  if (type(t) == "table") then
    print(tostring(t) .. " {")
    sub_printTable(t, "  ")
    print("}")
  else
    sub_printTable(t, "  ")
  end
end

-- Recursivly searches for a file starting at cwd and working up to root
-- Returns path or nill
-- Only good for file, not directories
function M.findFile(file, start)
  local current_dir = start
  if current_dir == nil then
    current_dir = vim.fn.getcwd()
  end

  while current_dir ~= "/" do
    local project_file = current_dir .. "/" .. file
    if vim.fn.filereadable(project_file) == 1 then
      return project_file
    end

    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end

  return nil   -- Not found
end

function M.GetParentPath(path)
    return vim.fn.fnamemodify(path, ":h")
end

-- Reads the entire file
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then return end

  local txt = file:read("*a")
  file:close()
  return txt
end

function M.exists(path)
  return vim.loop.fs_stat(path) ~= nil
end

function M.isSemanticVersion(version)
  if #version == 0 then return false end
  if not string.match(version, "%d+%.%d+%.%d+") then
    return false
  end
  return true
end

function M.parseSemanticVersion(version)
  if #version == 0 then return false end
  local maj, min, pat = string.match(version, "(%d+)%.(%d+)%.(%d+)")
  if maj and min and pat then
    return { major = maj, minor = min, patch = pat }
  end
end

-- synchronous shell command executation using vim.system()
function M.run(command)
  local obj = vim.system(command, { text = true }):wait()
  if obj.code ~= 0 then
    local cmd = table.concat(command, " ")
    print("Command " .. cmd .. " exited with code " .. obj.code)
    print("stdout " .. obj.stdout)
    print("stderr " .. obj.stderr)
    return false
  end
  return true
end

function M.scanDirectory(path, cb)
  -- TODO: return errors
  local list = {}

  local handle = vim.loop.fs_scandir(path)
  if not handle then
    print("Failed to scanDirectory directory: " .. path)
    return list
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if cb(name, type) then
      table.insert(list, name)
    end
  end
  return list
end

function M.ensure_directory(path)
    if vim.fn.isdirectory(path) == 0 then
        vim.fn.mkdir(path, 'p')
    end
end

return M
