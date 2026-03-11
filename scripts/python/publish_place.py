"""Publishes a built place file to a Roblox place via Open Cloud (versionType=Published).

Used by the deploy job. Reads ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID / ROBLOX_PLACE_ID
from the environment (scoped to the production GitHub Environment in CI).

Usage: python3 scripts/python/publish_place.py <path-to-place-file>
"""

import os
import sys
import json
import urllib.request

ROBLOX_API_KEY = os.environ["ROBLOX_API_KEY"]
ROBLOX_UNIVERSE_ID = os.environ["ROBLOX_UNIVERSE_ID"]
ROBLOX_PLACE_ID = os.environ["ROBLOX_PLACE_ID"]


def read_file(file_path):
    with open(file_path, "rb") as file:
        return file.read()


def publish_place(binary_path, universe_id, place_id):
    print(f"Publishing place {place_id} (universe {universe_id}) as a live version")
    request_headers = {
        "x-api-key": ROBLOX_API_KEY,
        "Content-Type": "application/xml",
        "Accept": "application/json",
    }
    url = (
        f"https://apis.roblox.com/universes/v1/{universe_id}"
        f"/places/{place_id}/versions?versionType=Published"
    )

    req = urllib.request.Request(
        url, data=read_file(binary_path), headers=request_headers, method="POST"
    )

    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode("utf-8"))
        return data.get("versionNumber")


if __name__ == "__main__":
    binary_file = sys.argv[1]
    version = publish_place(binary_file, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID)
    print(f"Published version {version} to place {ROBLOX_PLACE_ID}")
