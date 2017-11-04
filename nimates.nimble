# Package

version       = "0.0.1"
author        = "James Albert"
description   = "a client library for the Postmates API written in Nim"
license       = "Apache License 2.0"
srcDir        = "src"

# Dependencies

requires "nim >= 0.17.2"

task example, "running example":
  exec "cd examples && nim c -r basic.nim"

task docs, "generating docs":
  exec "nim doc -o:docs/nimates.html src/nimates.nim"
