local M = {}

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
    return { major = tonumber(maj), minor = tonumber(min), patch = tonumber(pat) }
  end
end

-- Return -1 if a > b, 0 if same, 1 if b > a
function M.compare_semantic_verions(a, b)
  if a.major ~= b.major then
    if a.major > b.major then
      return -1;
    elseif a.major < b.major then
      return 1;
    else
      return 0;
    end
  elseif a.minor ~= b.minor then
    if a.minor > b.minor then
      return -1;
    elseif a.minor < b.minor then
      return 1;
    else
      return 0;
    end
  elseif a.patch > b.patch then
    return -1;
  elseif a.patch < b.patch then
    return 1;
  else
    return 0;
  end
end

function M.string_split(str)
  local out = {}
  for line in str:gmatch("[^\n]+") do
    table.insert(out, line)
  end
  return out
end

-- synchronous shell command executation using vim.system()
function M.run(command, output_as_table)
  local result = vim.system(command, { text = true }):wait()

  -- print(table.concat(command, " "))

  -- local cmd = table.concat(command, " ")
  -- print("Command: " .. command .. " exited with code " .. result.code)
  -- print("stdout: " .. result.stdout)
  -- print("stderr: " .. result.stderr)
  if result.code ~= 0 then
    return false, result.stderr
  end
  return true, result.stdout
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

-- TODO: use this for joining paths
function M.join(...)
  return table.concat({...}, package.config:sub(1, 1))
end

return M
