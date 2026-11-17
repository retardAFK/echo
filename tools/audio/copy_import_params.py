"""Gives each foo_muffled.wav the import settings of foo.wav (loop, compression),
so a looping sound stays looping behind a wall (spec S-012, T-142).

    python tools/audio/copy_import_params.py   then   godot --headless --import
"""

import glob
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")


def params(text):
    return text[text.index("[params]") :]


for muffled in sorted(glob.glob(os.path.join(ROOT, "assets/audio/*/*_muffled.wav.import"))):
    clean = muffled.replace("_muffled.wav.import", ".wav.import")
    if not os.path.exists(clean):
        continue
    with open(muffled) as f:
        text = f.read()
    with open(clean) as f:
        wanted = params(f.read())
    if params(text) != wanted:
        with open(muffled, "w") as f:
            f.write(text[: text.index("[params]")] + wanted)
        print(os.path.relpath(muffled, ROOT))
