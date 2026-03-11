"""Publishes a built place file to a Roblox place via Open Cloud (versionType=Published).

Used by the deploy job. Reads ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID / ROBLOX_PLACE_ID
from the environment (scoped to the production GitHub Environment in CI).

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
