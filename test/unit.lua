local tests = {}

function tests.test_hello()
  print("test_hello")
  local particle = require("particle")
  print(particle.hello())
end

function tests.test_utils()
  print("test_hello")
  local utils = require("utils")
  print(utils.printTable({"asdf", "fdsfsd"}))
end

tests.test_hello()
tests.test_utils()
