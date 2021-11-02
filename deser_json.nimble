version     = "0.1.0"
author      = "gabbhack"
description = "JSON-Binding for deser"
license     = "MIT"

srcDir = "src"

requires "nim >= 1.6.0, faststreams, deser >= 0.1.6"

task test, "Run tests":
  exec "testament all"
