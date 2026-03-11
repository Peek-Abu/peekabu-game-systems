"""Uploads a built place to the TEST place and runs a Luau task (TestEZ) against it.

Used by the CI test job. Reads ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID / ROBLOX_PLACE_ID
from the environment. Exits non-zero if the task does not complete successfully.

Usage: python3 scripts/python/upload_and_run_task.py <path-to-place-file> <path-to-luau-script>
"""

import os
import sys

from luau_execution_task import createTask, pollForTaskCompletion, getTaskLogs
from roblox_open_cloud import read_file, upload_place_version

ROBLOX_API_KEY = os.environ["ROBLOX_API_KEY"]
ROBLOX_UNIVERSE_ID = os.environ["ROBLOX_UNIVERSE_ID"]
ROBLOX_PLACE_ID = os.environ["ROBLOX_PLACE_ID"]


def run_luau_task(universe_id, place_id, place_version, script_file):
    print("Executing Luau task")
    script_contents = read_file(script_file).decode("utf8")

    task = createTask(
        ROBLOX_API_KEY, script_contents, universe_id, place_id, place_version
    )
    task = pollForTaskCompletion(ROBLOX_API_KEY, task["path"])
    logs = getTaskLogs(ROBLOX_API_KEY, task["path"])

    print(logs)

    if task["state"] == "COMPLETE":
        print("Lua task completed successfully")
        exit(0)
    else:
        print("Luau task failed", file=sys.stderr)
        exit(1)


if __name__ == "__main__":
    universe_id = ROBLOX_UNIVERSE_ID
    place_id = ROBLOX_PLACE_ID
    binary_file = sys.argv[1]
    script_file = sys.argv[2]

    place_version = upload_place_version(
        ROBLOX_API_KEY, universe_id, place_id, binary_file
    )
    run_luau_task(universe_id, place_id, place_version, script_file)
