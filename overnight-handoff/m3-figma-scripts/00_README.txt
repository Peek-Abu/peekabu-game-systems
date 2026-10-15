Pending Figma build scripts for "Cleanup Crew — UI (for approval)"
File: https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4  (page "Screens" = 2:5)

Written AFTER the Figma MCP Starter-plan tool-call limit was hit, so they are UNTESTED.
To apply: for each of 2_depot.js, 3_queue.js, 4_catch.js, 5_results.js, send
  cat _prelude.js <screen>.js
as the `code` of one use_figma call (fileKey PYtXsNlpV1MW2nOVx0wXl4, skillNames resource:figma-use).
Each script deletes its own earlier frames first, so it is safe to re-run.
Then get_screenshot each returned frame id and fix overlaps/clipping.
Component ids used (Style page): sticky 5:4, stamp 5:7, button set 5:17, mobile button set 5:26,
pocket slot set 5:31, punch clock 5:32, manila tab 5:47.
