# Package

version       = "0.0.1"
author        = "James Albert"
description   = "a client library for the Postmates API written in Nim"
license       = "Apache License 2.0"
bin           = @["nimates"]

# Dependencies

requires "nim >= 0.17.2"

task clean, "cleaning project":
  exec "rm -rf nimates nimcache"

task run, "running project":
  exec "nimble clean"
  exec "nimble build"
  exec "./nimates"
