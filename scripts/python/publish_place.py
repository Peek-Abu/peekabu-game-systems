"""Publishes a built place file to a Roblox place via Open Cloud (versionType=Published).

Not wired into CI: automated deploy was removed (production is published manually from Studio so
artist-owned place content isn't overwritten by a code-only build — see docs/ci-cd.md). This helper
is kept for a future fully-managed CD pipeline and for one-off manual publishes. Reads
ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID / ROBLOX_PLACE_ID from the environment.

Usage: python3 scripts/python/publish_place.py <path-to-place-file>
"""

import os
import sys

from roblox_open_cloud import upload_place_version

ROBLOX_API_KEY = os.environ["ROBLOX_API_KEY"]
ROBLOX_UNIVERSE_ID = os.environ["ROBLOX_UNIVERSE_ID"]
ROBLOX_PLACE_ID = os.environ["ROBLOX_PLACE_ID"]


if __name__ == "__main__":
    binary_file = sys.argv[1]
    version = upload_place_version(
        ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID, binary_file, publish=True
    )
    print(f"Published version {version} to place {ROBLOX_PLACE_ID}")
