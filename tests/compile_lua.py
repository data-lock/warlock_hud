"""Compile every Lua file in TOC load order with LuaJIT's Lua 5.1 parser."""

from pathlib import Path
from lupa.luajit21 import LuaRuntime

lua = LuaRuntime()
compile_source = lua.eval("function(source) return assert(loadstring(source)) end")
files = [Path(line.strip()) for line in Path("Warlock_Hud.toc").read_text().splitlines()
         if line.strip().endswith(".lua")]
for path in files:
    compile_source(path.read_text(encoding="utf-8"))
print(f"{len(files)} addon Lua files compile")
