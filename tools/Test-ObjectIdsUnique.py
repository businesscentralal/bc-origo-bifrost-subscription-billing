"""Local harness mirroring tools/Test-ObjectIdsUnique.ps1.

Used only to exercise the guard logic on this Linux worker; the shipped guard
is the PowerShell script, which runs in the Source Guards pipeline.
"""
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DECL = re.compile(
    r"^\s*(?:global\s+)?(?:codeunit|page|table|enum|query|report|permissionset|xmlport"
    r"|dashlet|chart|interface|tableextension|pageextension|enumextension|reportextension"
    r"|permissionsetextension)\s+(\d+)",
    re.MULTILINE,
)

failures = []
for app_root in ("app", "test"):
    src_root = REPO_ROOT / app_root / "src"
    declarations = {}
    count = 0
    for path in sorted(src_root.rglob("*.al")):
        count += 1
        for match in DECL.finditer(path.read_text(encoding="utf-8")):
            obj_id = match.group(1)
            if obj_id in declarations:
                failures.append(
                    f"{app_root}: duplicate object ID {obj_id} ({path.name} and {declarations[obj_id]})"
                )
            else:
                declarations[obj_id] = path.name
    if count == 0:
        raise SystemExit(f"{app_root}/src: no .al files found; guard input is wrong.")

if failures:
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    raise SystemExit(f"Object ID uniqueness check failed with {len(failures)} duplicate(s).")

print("Object ID uniqueness check passed: no duplicate object IDs within any app.")
