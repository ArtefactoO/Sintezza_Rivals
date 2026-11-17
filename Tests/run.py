"""Check Rivals retention, event refreshes, and combat history with Lua 5.1."""
from argparse import ArgumentParser
import json
from pathlib import Path
import re

from lupa.lua51 import LuaRuntime


def plain(value):
    if not hasattr(value, "items"):
        return value
    entries = dict(value.items())
    if entries and all(isinstance(key, int) for key in entries):
        return [plain(entries[key]) for key in sorted(entries)]
    return {str(key): plain(item) for key, item in entries.items()}


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, help="Optional prior Sightings.lua for differential checks.")
    parser.add_argument("--baseline-minimap", type=Path, help="Optional prior Minimap.lua for differential checks.")
    parser.add_argument("--output", type=Path, help="Write detailed fixture results as JSON.")
    args = parser.parse_args()
    addon = Path(__file__).resolve().parents[1]
    runtime = LuaRuntime(unpack_returned_tuples=True)
    compile_lua = runtime.eval("function(source, name) local fn, err = loadstring(source, name); assert(fn, err) end")
    count = 0
    for source in sorted(addon.rglob("*.lua")):
        relative = source.relative_to(addon)
        if any(part.startswith(".") for part in relative.parts) or relative.parts[0] == "Tests":
            continue
        compile_lua(source.read_text(encoding="utf-8-sig"), relative.as_posix())
        count += 1
    print(f"PASS: Lua 5.1 syntax, {count} production files")
    toc = (addon / "Sintezza_Rivals.toc").read_text(encoding="utf-8-sig")
    version = re.search(r"(?m)^## Version:\s*(\S+)", toc)[1]
    versions = re.findall(r"(?m)^## (\S+)", (addon / "CHANGELOG.md").read_text(encoding="utf-8-sig"))
    assert next(section for section in versions if section != "Unreleased") == version
    for line in toc.splitlines():
        if line.strip() and not line.startswith("#"):
            assert (addon / line.strip().replace("\\", "/")).is_file(), line
    print(f"PASS: TOC and version {version}")

    def read(relative):
        return (addon / relative).read_text(encoding="utf-8-sig")

    def run(name, *values):
        return runtime.execute(read("Tests/" + name + ".lua"), *values)

    report = {}
    current = read("PvP/Modules/Sightings.lua")
    previous = args.baseline.read_text(encoding="utf-8-sig") if args.baseline else None
    checks, scenarios = run("Observations", current, previous)
    report["observations"] = {"checks": checks, "scenarios": scenarios}
    print(f"PASS: {checks} observation assertions, {scenarios} scenarios")

    checks, scenarios, metrics = run("Retention", current)
    report["retention"] = {"checks": checks, "scenarios": scenarios, "metrics": plain(metrics)}
    print(f"PASS: {checks} retention assertions, {scenarios} scenarios")

    old_minimap = args.baseline_minimap.read_text(encoding="utf-8-sig") if args.baseline_minimap else None
    checks, scenarios, metrics = run("MinimapScale", read("PvP/Map/Minimap.lua"), old_minimap)
    report["minimap"] = {"checks": checks, "scenarios": scenarios, "metrics": plain(metrics)}
    print(f"PASS: {checks} minimap assertions, {scenarios} scenarios")

    checks = run("NameplateQueue", read("Nameplates.lua"), read("PvPIntegration.lua"))
    report["nameplateQueue"] = {"checks": checks}
    print(f"PASS: {checks} marker-queue assertions")

    paths = ("History.lua", "PvP/Modules/Deaths.lua", "PvP/Modules/Sightings.lua", "PvPIntegration.lua", "Data.lua")
    combat_sources = {path: read(path) for path in paths}
    combat_sources["Theme/DataTransfer.lua"] = (addon.parent / "Sintezza_Theme/DataTransfer.lua").read_text(encoding="utf-8-sig")
    sources = runtime.table_from(combat_sources)
    crowd = plain(run("CrowdDamage", sources))
    assert not crowd.get("failures"), crowd["failures"]
    report["crowdDamage"] = crowd
    print(f"PASS: {crowd['checks']} combat-crowd assertions")
    ui_paths = ("PvP/Core/Locales.lua", "PvP/Modules/Watchlist.lua", "PvP/Modules/Deaths.lua",
                "PvP/UI/Card.lua", "PvP/UI/List.lua", "PvP/Options/Options.lua", "PvP/Options/Pages.lua", "PvPIntegration.lua", "Options.lua",
                "PvP/Theme/Widgets.lua", "PvP/UI/Popups.lua", "PvP/Modules/HUD.lua", "PvP/Map/Map.lua")
    ui_checks, ui_captures = run("UIWorkflow", runtime.table_from({path: read(path) for path in ui_paths}))
    report["uiWorkflow"] = {"checks": ui_checks, "captures": plain(ui_captures)}
    print(f"PASS: {ui_checks} card, settings, ignore and class-color assertions (English and Russian)")
    if args.output:
        args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
