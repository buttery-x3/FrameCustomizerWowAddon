"""Build an allowlisted, deterministic release; validate exact ZIP contents."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "FrameCustomizer"
subprocess.run([sys.executable, str(ROOT / "scripts/check.py")], cwd=ROOT, check=True)
toc = (SOURCE / "FrameCustomizer.toc").read_text(encoding="utf-8")
version = re.search(r"^## Version: ([\d.]+)$", toc, re.M).group(1)
files = ["FrameCustomizer.toc", "LICENSE"] + [s.strip() for s in toc.splitlines() if s.strip() and not s.startswith("#")]
assert len(files) == len(set(files))
destination = ROOT / "dist"
destination.mkdir(exist_ok=True)
path = destination / f"FrameCustomizer-{version}.zip"
with ZipFile(path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for relative in sorted(files):
        source = (SOURCE / relative).resolve()
        assert source.is_relative_to(SOURCE.resolve()) and source.is_file()
        entry = ZipInfo("FrameCustomizer/" + relative, (2026, 9, 30, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o644 << 16
        archive.writestr(entry, source.read_bytes())
with ZipFile(path) as archive:
    expected = {"FrameCustomizer/" + name for name in files}
    assert set(archive.namelist()) == expected
    assert len(archive.namelist()) == len(expected)
    assert {name.split("/")[0] for name in archive.namelist()} == {"FrameCustomizer"}
    assert archive.testzip() is None
    for name in expected:
        assert archive.read(name) == (ROOT / name).read_bytes()
digest = hashlib.sha256(path.read_bytes()).hexdigest()
path.with_suffix(".zip.sha256").write_text(digest + "  " + path.name + "\n", encoding="ascii")
print(f"PACKAGE PASS: {path} ({path.stat().st_size} bytes; {len(files)} allowlisted files)")
print("SHA256 " + digest)

