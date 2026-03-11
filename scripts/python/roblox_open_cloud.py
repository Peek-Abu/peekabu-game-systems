"""Shared Open Cloud helpers for the place-upload scripts.

`upload_and_run_task.py` (test job) and `publish_place.py` (deploy job) both push a built
place file to Roblox via the same versions endpoint — the only difference is versionType
(Saved vs Published). This module holds that one upload implementation so the two scripts
can't drift, and gives it the retry + HTTP-error-body reporting that `luau_execution_task.py`
already has for its own requests (a transient upload failure otherwise surfaced as a raw
traceback with no server message, failing CI opaquely).
"""

import json
import sys
import time
import urllib.error
import urllib.request

# The Open Cloud place-versions endpoint. versionType is "Saved" (test uploads) or
# "Published" (a live deploy).
_VERSIONS_URL = (
    "https://apis.roblox.com/universes/v1/{universe_id}"
    "/places/{place_id}/versions?versionType={version_type}"
)


def read_file(file_path):
    """Reads a file as raw bytes (place files are binary xml/rbxlx)."""
    with open(file_path, "rb") as file:
        return file.read()


def upload_place_version(
    api_key, universe_id, place_id, binary_path, publish=False, max_attempts=3
):
    """Uploads a place file and returns its new version number.

    publish=False saves a new version (test place); publish=True makes it the live version.
    Retries transient failures with linear backoff; on an HTTP error the server's response
    body is included in the raised message so CI logs show *why* it was rejected instead of a
    bare status code.
    """
    version_type = "Published" if publish else "Saved"
    url = _VERSIONS_URL.format(
        universe_id=universe_id, place_id=place_id, version_type=version_type
    )
    headers = {
        "x-api-key": api_key,
        "Content-Type": "application/xml",
        "Accept": "application/json",
    }
    body = read_file(binary_path)

    print(f"Uploading place {place_id} (universe {universe_id}) as a {version_type} version")

    for attempt in range(1, max_attempts + 1):
        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("versionNumber")
        except urllib.error.HTTPError as e:
            # 4xx (bad request/auth/quota) won't fix themselves on retry — fail immediately
            # with the server's explanation. 5xx and rate limits are worth another attempt.
            server_body = e.read().decode("utf-8", errors="replace")
            if e.code < 500 and e.code != 429:
                print(
                    f"Place upload rejected (HTTP {e.code}), response body:\n{server_body}",
                    file=sys.stderr,
                )
                sys.exit(1)
            print(
                f"Place upload attempt {attempt}/{max_attempts} failed "
                f"(HTTP {e.code}), response body:\n{server_body}",
                file=sys.stderr,
            )
        except urllib.error.URLError as e:
            print(
                f"Place upload attempt {attempt}/{max_attempts} failed: {e.reason}",
                file=sys.stderr,
            )

        if attempt < max_attempts:
            time.sleep(attempt)

    print(f"Place upload failed after {max_attempts} attempts", file=sys.stderr)
    sys.exit(1)
