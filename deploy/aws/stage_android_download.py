"""Stage the approved APK alongside the static download page, without tracking binaries."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--web-root", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2] / "frontend/web/descargar"
    manifest = json.loads((source / "apk.json").read_text(encoding="utf-8"))
    apk = args.apk.resolve(strict=True)
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if apk.stat().st_size != manifest["bytes"] or digest != manifest["sha256"]:
        parser.error("APK size or SHA-256 differs from the approved manifest; nothing copied")
    web_root = args.web_root.resolve(strict=True)
    if not (web_root / "index.html").is_file():
        parser.error("--web-root must contain the built Flutter index.html")
    target = web_root / "descargar"
    target.mkdir(exist_ok=True)
    for filename in ("index.html", "apk.json"):
        if (source / filename).resolve() != (target / filename).resolve():
            shutil.copyfile(source / filename, target / filename)
    destination = target / manifest["filename"]
    if destination.resolve() != apk:
        shutil.copyfile(apk, destination)
    print(f"Staged Android {manifest['version']} ({manifest['version_code']}), SHA-256 {digest}")


if __name__ == "__main__":
    main()
