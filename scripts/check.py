"""Run real Lua 5.1 production code via pinned Lupa; no Blizzard dump execution."""
from pathlib import Path
import re
import sys
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "FrameCustomizer"
toc = (ADDON / "FrameCustomizer.toc").read_text(encoding="utf-8")
files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert "## Interface: 16001" in toc
assert "## SavedVariables: FrameCustomizerDB" in toc
assert len(files) == len(set(files))
lua = LuaRuntime(unpack_returned_tuples=True)
compile_source = lua.eval("function(source, name) local f,e=loadstring(source,name); if not f then error(e) end; return true end")
for path in sorted(ADDON.rglob("*.lua")):
    compile_source(path.read_text(encoding="utf-8"), "@" + path.relative_to(ROOT).as_posix())
for file in files:
    assert (ADDON / file).is_file(), f"Missing TOC reference: {file}"
assert set(files) == {p.relative_to(ADDON).as_posix() for p in ADDON.rglob("*.lua")}
assert not list(ADDON.rglob("*.xml")), "Add XML validation before shipping XML"
print(f"SYNTAX/TOC: {len(files)} Lua files compile under Lua 5.1; all references valid; no addon XML", flush=True)

def load(runtime, file, namespace):
    source = (ROOT / file).read_text(encoding="utf-8")
    return runtime.execute("return assert(loadstring(...))", source)("FrameCustomizer", namespace)

fc = lua.table()
for file in files:
    if file.startswith("Core/"):
        load(lua, "FrameCustomizer/" + file, fc)
load(lua, "tests/FakeAdapter.lua", fc)
core_count = load(lua, "tests/core_spec.lua", fc)

native = LuaRuntime(unpack_returned_tuples=True)
ns = native.table()
load(native, "tests/native_env.lua", ns)
for file in files:
    load(native, "FrameCustomizer/" + file, ns)
native_count = load(native, "tests/native_spec.lua", ns)
print(f"ALL CHECKS PASSED: {core_count} core scenarios; {native_count} native-adapter/load/UI-recording scenarios", flush=True)
