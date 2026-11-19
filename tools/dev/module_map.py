#!/usr/bin/env python3
"""Module map of the game (spec S-022, T-430), for people and agents.

  python3 tools/dev/module_map.py            # who depends on whom, per module
  python3 tools/dev/module_map.py --sizes    # biggest scripts (lines)
  python3 tools/dev/module_map.py --refs Gurney   # every file naming a module

A module is a folder of game/ (game/entities/<name> counts as its own module).
A dependency is a class_name or autoload of another module named in the code
(comments left out). Run from the repository root.
"""

import os
import re
import sys
from collections import Counter, defaultdict

AUTOLOADS = {
    "NoiseBus": "game/autoload/noise_bus.gd",
    "SoundSpace": "game/autoload/sound_space.gd",
    "NetSession": "game/net/net_session.gd",
    "Settings": "game/settings/user_settings.gd",
}
SEARCHED = ("game", "tests", "tools", "art_src", "assets", "specs", "docs")
TEXT_EXT = (".gd", ".tscn", ".tres", ".csv", ".py", ".md", ".yml", ".cfg")


def scripts(root="game"):
    for folder, _, names in os.walk(root):
        for name in sorted(names):
            if name.endswith(".gd"):
                yield os.path.join(folder, name)


def module_of(path):
    parts = path.split(os.sep)
    if len(parts) > 3 and parts[1] == "entities":
        return "/".join(parts[1:3])
    return parts[1]


def class_names():
    found = dict(AUTOLOADS)
    for path in scripts():
        with open(path, encoding="utf8") as handle:
            match = re.search(r"^class_name (\w+)", handle.read(), re.M)
        if match:
            found[match.group(1)] = path
    return found


def dependencies():
    names = class_names()
    deps = defaultdict(Counter)
    for path in scripts():
        with open(path, encoding="utf8") as handle:
            code = re.sub(r"#.*", "", handle.read())
        for name, owner in names.items():
            if module_of(owner) != module_of(path) and re.search(rf"\b{name}\b", code):
                deps[module_of(path)][module_of(owner)] += 1
    return deps


def print_map():
    deps = dependencies()
    users = Counter()
    for module in deps:
        for target in deps[module]:
            users[target] += 1
    for module in sorted(deps):
        targets = ", ".join(name for name, _ in deps[module].most_common())
        print(f"{module} ({len(deps[module])} deps, used by {users[module]}) -> {targets}")


def print_sizes(count=25):
    sizes = []
    for root in ("game", "tools", "tests"):
        for path in scripts(root):
            with open(path, encoding="utf8") as handle:
                sizes.append((sum(1 for _ in handle), path))
    for lines, path in sorted(sizes, reverse=True)[:count]:
        print(f"{lines:6} {path}")


def print_refs(name):
    snake = re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()
    pattern = re.compile(rf"\b({name}|{snake})\b")
    for root in SEARCHED:
        for folder, _, names in os.walk(root):
            for file_name in sorted(names):
                path = os.path.join(folder, file_name)
                if not file_name.endswith(TEXT_EXT):
                    if snake in file_name.lower():
                        print(f"file {path}")
                    continue
                with open(path, encoding="utf8", errors="ignore") as handle:
                    hits = sum(1 for line in handle if pattern.search(line))
                if hits:
                    print(f"{hits:4} {path}")


if __name__ == "__main__":
    if "--sizes" in sys.argv:
        print_sizes()
    elif "--refs" in sys.argv:
        print_refs(sys.argv[sys.argv.index("--refs") + 1])
    else:
        print_map()
