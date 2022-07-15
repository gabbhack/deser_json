version     = "0.1.0"
author      = "gabbhack"
description = "JSON-Binding for deser"
license     = "MIT"

srcDir = "src"

requires "nim >= 1.6.0, jsony == 1.1.3"

task test, "Run tests":
  exec "testament all"
