# Social perks and badges (Odd Hours)

Owner picks (2026-10-27, memory `social-rewards-decisions`): group perk = one-time Gleam; favorites and likes are
asked at a happy moment and never rewarded; invites = 2x XP with a Roblox friend plus a small capped referral; the
picked badge set. Crew hosting (host-run truck, truck cosmetics, 6-player pass) is not in this plan: it needs its own
design.

## Batch A: social perks

Tuning (SocialConstants, all one-line edits):

| What | Value |
|---|---|
| Group | Icey Labs, id 189923277 |
| Group perk | 100 Gleam, once per account |
| Referral | the invited friend finishes their first shift: they get 50 Gleam, the inviter gets 50 Gleam |
| Referral cap | the inviter is paid for 5 friends at most |
| Friend bonus | x2 shift XP when anyone else on the shift's crew is a Roblox friend |
| Ask | after a met contract, at most once every 3 days, never once the game is a favorite |

Rules:
- Group: checked on the server (`Player:IsInGroupAsync`) on join and when the client says the join prompt closed.
  Paid once (`social.groupPaid`) in one transaction with the Gleam.
- Referral: the client's invite carries `LaunchData = "ref:<userId>"`. On join, a player who has never finished a
  shift (`rank.xp == 0`) and has no referrer records the inviter from LaunchData, never
  themselves. When a shift review lands, each crew member with a referrer and `referralPaid == false` is paid and
  marked paid; the inviter is paid in the same transaction only when they are in this server and under the cap.
- Friend bonus: the server caches friend pairs on join (`Player:IsFriendsWithAsync`, SocialFriendTracker). The
  review's crew lines carry `friend`, so the server's award and the results card read the same "Friends x2" line.
- Ask: a small card on the results screen: "Having fun? Tap FAVORITE to find Odd Hours fast. A thumbs up helps us too!"
  FAVORITE opens Roblox's favorite prompt (`AvatarEditorService:PromptSetFavorite(PlaceId, Asset, true)`). Nothing
  is paid. The server stores when it was last asked (`social.askedAt`).

New modules:

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Social | shared | Data | SocialConstants | group id, rewards, caps, ask spacing, launch-data prefix |
| Social | shared | Net | SocialEvents | client to server: group prompt closed, ask shown |
| Social | shared | Rules | SocialRules | pure: fresh/validate the slice, parse launch data, referral and ask decisions |
| Social | server | (root) | SocialServiceServer | the `social` slice, group perk, referral pay-out, friend-pair cache fill |
| Social | server | State | SocialFriendTracker | which players in this server are Roblox friends |
| Social | client | (root) | SocialServiceClient | invite prompt, group prompt, favorite ask |
| Social | client | State | SocialAskStore | whether the ask card is up |
| UI | client | Screens/Social | SocialAskCard | the results screen's favorite/like card |
| UI | client | Screens/Social | SocialPerksPanel | the hub's INVITE FRIENDS and JOIN GROUP buttons |

Changed: PlayerDataTypes (`Social`), PlayerDataConstants (default), StateSyncSliceRegistry, StateSyncClientStore,
ShiftTypes (`friend` on CrewStats and CrewLine), ShiftResultsUtils.build, ShiftReviewSystem (marks friends),
RankTypes/RankFormulas/RankConstants (the "Friends x2" line, `XP.friendMultiplier`).

## Batch B: badges

Badge keys, wired in code; each awards only once its Roblox badge id is filled in `OddHoursBadges` (a 0 id is skipped
with one warning at boot). The ids come from the Creator Dashboard after the badge art is made.

| Key | Name | When |
|---|---|---|
| hired | Hired! | first join |
| clocked-in | Clocked In | first finished shift |
| hide-and-squeak | Hide and Squeak | the Manager gives up a chase while you are hidden |
| clean-sweep | Clean Sweep | contract met and the whole crew clocked out |
| night-shift-squad | Night Shift Squad | finish a shift with 4 players |
| rank-2 .. rank-7 | one per rank | reach Sweeper .. Big Boss |
| epic-pull | Lucky Locker | first Epic or better from a Locker |
| legendary-pull | Super Lucky Locker | first Legendary or better from a Locker |
| new-look | New Look | equip a skin that is not Classic |
