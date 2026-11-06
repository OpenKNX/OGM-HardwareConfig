"""Prüft die Gerätedateien der Device-Registry (devices/*.json).

Fehler (Exit-Code 1):
  1. Datei ist kein gültiges JSON oder verletzt devices/schema.json; Dateiname ist nicht gleich id.
  2. Kein Makro in den Headern ergibt diese DEVICE_ID.
  3. name ist nicht gleich dem DEVICE_NAME dieser Makros (bei mehreren Makros mit derselben ID müssen alle passen).

Makros ohne Gerätedatei sind kein Fehler. Die README-Regeln der Header (Makro aus ID abgeleitet, Längen)
prüft dieses Skript nicht. Bilder und devices.json liegen im Repo OpenKNX/OpenKNX.github.io und werden dort geprüft.

DEVICE_ID und DEVICE_NAME werden wie im Firmware-Build ermittelt: Jedes Makro, das in einer #if/#ifdef/#elif-Zeile
vorkommt, wird einzeln mit -D<Makro> durch den C-Präprozessor geschickt (HardwareConfig.h).

Aufruf: python scripts/registry/check_devices.py [--repo .] [--cpp cpp]
Braucht das Python-Paket jsonschema und den C-Präprozessor cpp (gcc).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

from jsonschema import Draft202012Validator

COND = re.compile(r"^\s*#\s*(?:if|ifdef|elif|ifndef)\b(.*)$")
MACRO = re.compile(r"\b[A-Z][A-Z0-9_]{2,}\b")
NOT_DEVICE = {"DEVICE_ID", "DEVICE_NAME", "PREFIX_ID", "PREFIX_NAME"}
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')

errors = []


def error(path, msg):
    errors.append((path, msg))
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::error file={path}::{msg}")
    else:
        print(f"FEHLER {path}: {msg}")


def literal(text):
    """String-Literal(e) aus der Präprozessor-Ausgabe, None wenn es kein reines Literal ist."""
    parts = LITERAL.findall(text or "")
    if not parts or LITERAL.sub("", text).strip():
        return None
    return "".join(parts)


def header_devices(repo, cpp):
    """DEVICE_ID → {DEVICE_NAME: [Makros]} für alle Makros aus den Headern."""
    inc = os.path.join(repo, "include")
    candidates = set()
    for root, _, files in os.walk(inc):
        for f in files:
            if not f.endswith(".h"):
                continue
            with open(os.path.join(root, f), encoding="utf-8") as fh:
                for line in fh:
                    m = COND.match(line)
                    if m:
                        candidates.update(x for x in MACRO.findall(m.group(1)) if x not in NOT_DEVICE)

    result = {}
    fd, probe = tempfile.mkstemp(suffix=".c")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write('#include "HardwareConfig.h"\n@@ID@@ DEVICE_ID\n@@NAME@@ DEVICE_NAME\n')
        for macro in sorted(candidates):
            r = subprocess.run([cpp, "-P", "-I", inc, f"-D{macro}", probe],
                               capture_output=True, text=True, encoding="utf-8")
            if r.returncode != 0:
                continue  # Hilfs- und Optionsmakros, die allein nicht übersetzbar sind
            dev_id = name = None
            for line in r.stdout.splitlines():
                if line.startswith("@@ID@@"):
                    dev_id = literal(line[6:].strip())
                elif line.startswith("@@NAME@@"):
                    name = literal(line[8:].strip())
            if dev_id is not None:
                result.setdefault(dev_id, {}).setdefault(name, []).append(macro)
    finally:
        os.unlink(probe)
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--cpp", default="cpp")
    args = ap.parse_args()

    devdir = os.path.join(args.repo, "devices")
    with open(os.path.join(devdir, "schema.json"), encoding="utf-8") as fh:
        validator = Draft202012Validator(json.load(fh))

    files = sorted(f for f in os.listdir(devdir) if f.endswith(".json") and f != "schema.json")
    devices = {}
    for f in files:
        path = f"devices/{f}"
        try:
            with open(os.path.join(devdir, f), encoding="utf-8-sig") as fh:
                data = json.load(fh)
        except (OSError, ValueError) as e:
            error(path, f"kein gültiges JSON: {e}")
            continue
        valid = True
        for e in sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path)):
            where = "/".join(str(p) for p in e.absolute_path) or "(Wurzel)"
            error(path, f"Schema: {where}: {e.message}")
            valid = False
        if isinstance(data, dict) and data.get("id") != f[:-5]:
            error(path, f"Dateiname passt nicht zu id \"{data.get('id')}\"")
            valid = False
        if valid:
            devices[data["id"]] = (path, data)

    headers = header_devices(args.repo, args.cpp)
    for dev_id, (path, data) in devices.items():
        names = headers.get(dev_id)
        if not names:
            error(path, f"kein Makro in den Headern ergibt DEVICE_ID \"{dev_id}\"")
            continue
        for name, macros in sorted(names.items(), key=lambda x: str(x[0])):
            if name != data["name"]:
                error(path, f"name \"{data['name']}\" passt nicht zu DEVICE_NAME \"{name}\" ({', '.join(macros)})")

    print(f"{len(files)} Gerätedateien geprüft, {len(errors)} Fehler")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
