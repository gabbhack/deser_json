version     = "0.1.0"
author      = "gabbhack"
description = "JSON-Binding for deser"
license     = "MIT"

srcDir = "src"

requires "nim >= 1.6.0, deser >= 0.2.0, jsony == 1.1.3"

task test, "Run tests":
  exec "testament all"

task docs, "Generate docs":
  rmDir "docs"
  exec "nimble doc2 --outdir:docs --project --git.url:https://github.com/gabbhack/deser_json --git.commit:master --index:on src/deser_json"
