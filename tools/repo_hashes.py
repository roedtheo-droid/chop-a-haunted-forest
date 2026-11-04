"""Print "<Studio path> <hash> <length>" for every script in src/.

Usage:
  python tools/repo_hashes.py                 # print the list
  python tools/repo_hashes.py studio.txt      # compare with the output of tools/studio_hashes.luau

Windows line endings are turned into plain ones first, because Studio stores scripts that way.
"""
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
STUDIO_PLACE = {
    "shared": "ReplicatedStorage.Shared",
    "server": "ServerScriptService.Server",
    "client": "StarterPlayer.StarterPlayerScripts.Client",
}


def fnv1a(data: bytes) -> int:
    x = 2166136261
    for byte in data:
        x ^= byte
        x = (x * 16777619) & 0xFFFFFFFF
    return x


def repo_scripts() -> dict:
    found = {}
    for folder, _, files in os.walk(ROOT):
        for name in files:
            if not name.endswith(".luau"):
                continue
            path = os.path.join(folder, name)
            parts = os.path.relpath(path, ROOT).split(os.sep)
            base = name.removesuffix(".server.luau").removesuffix(".client.luau").removesuffix(".luau")
            full = ".".join([STUDIO_PLACE[parts[0]]] + parts[1:-1] + ([] if base == "init" else [base]))
            data = open(path, "rb").read().replace(b"\r\n", b"\n")
            found[full] = (fnv1a(data), len(data))
    return found


def main() -> None:
    repo = repo_scripts()
    if len(sys.argv) < 2:
        for full in sorted(repo):
            print(full, *repo[full])
        return
    studio = {}
    for line in open(sys.argv[1], encoding="utf-8"):
        bits = line.split()
        if len(bits) == 3:
            studio[bits[0]] = (int(bits[1]), int(bits[2]))
    same = True
    for full in sorted(set(repo) | set(studio)):
        if full not in studio:
            print("only in src/:   ", full); same = False
        elif full not in repo:
            print("only in Studio: ", full); same = False
        elif repo[full] != studio[full]:
            print("different:      ", full); same = False
    print("Studio and src/ match." if same else "Copy the scripts above from Studio into src/.")


if __name__ == "__main__":
    main()
