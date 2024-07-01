local M = {}

function M.setup(settings, env)
  local ENV_PATH = env["compiler_path"] .. ":" .. os.getenv("PATH")

  local Commands = require("commands")
  local overseer = require("overseer")
  local register_command = function(name, command, descr)
    local cmd = command(settings, env)
    -- print(cmd)
    overseer.register_template({
      name = name,
      builder = function()
        return {
          name = name,
          cmd = cmd,
          components = { "default" },
          env = {PATH = ENV_PATH},
        }
      end,
      description = descr,
    })
  end

  register_command("Particle Compile User", Commands.compile_user, "Particle compile-user")
  register_command("Particle Flash User", Commands.flash_user, "Particle flash-user")
  register_command("Particle Clean User", Commands.clean_user, "Particle clean-user")

-- TODO:These all commands are incomplete
  -- register_command("Particle Compile All", Commands.compile_all, "Particle compile-all")
  -- register_command("Particle Flash All", Commands.flash_all, "Particle flash-all")
  -- register_command("Particle Clean All", Commands.clean_all, "Particle clean-all")

  -- register_command("Particle Compile Debug", Commands.compile_all, "Particle compile-debug")
  -- register_command("Particle Flash Debug", Commands.flash_debug, "Particle flash-debug")
  -- register_command("Particle Clean Debug", Commands.clean_debug, "Particle clean-debug")
end

return M






















