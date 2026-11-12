# Odd Hours: Published Test, Friday Nov 13, 2026

A step-by-step guide for playing the published game with your brothers and sisters. You don't need to be a
programmer to follow it. Do the steps in order.

## What you need to know first

- **Saving works in the published game.** You don't need to turn on any setting for it.
- **Saving never works in Studio. That's on purpose.** Studio uses a pretend save, so a test can never
  break a real save. "My progress didn't save" in Studio is expected. It isn't a bug.
- **Leave "Enable Studio Access to API Services" OFF.** It would not make Studio save, because the game
  always uses the pretend save in Studio. Roblox also advises keeping it off for a live game.
- **Everyone starts with a new save.** The game now uses a new save store (`PlayerStore_v2`). Saves from
  the old published version, yours and your brother's, are never loaded again. You don't need to delete
  anything.
- **Training with two people only works in the published game.** Studio can't move players between
  places, so in Studio the lobby and the shift run in one server. Riding a truck between the two places
  only happens in the published game.

## 1. Sync the code into both places

Before you start, wait until the coordinator says the new code has been pulled.

1. Open the **Odd Hours** place (the lobby) in Studio.
2. In the Rojo plugin, connect to port **34872**. Wait until it says it is synced.
3. Open the **Odd Hours: Shift** place in Studio.
4. In the Rojo plugin, connect to port **34873**. Wait until it says it is synced.

## 2. Publish both places

Publish **both** places. Each one runs the code you synced into it, so if one isn't published, it is
still running old code.

1. In the **Odd Hours** window: File → Publish to Roblox. Wait for "published".
2. In the **Odd Hours: Shift** window: File → Publish to Roblox. Wait for "published".

## 3. Check the settings (nothing to switch on)

Nothing has to be switched on for saving or for riding the trucks between places. Check that these look
right:

| Setting | Where | What it should be |
|---|---|---|
| Enable Studio Access to API Services | Studio: File → Game Settings → Security | **OFF** (not needed) |
| Allow Third Party Teleports | Studio: File → Game Settings → Security | **OFF** is fine. Both places are in the same game, so the trucks work without it. |
| Content questionnaire (Maturity & Compliance) | Creator Dashboard → Odd Hours → Audience | **Done.** Roblox limits who can play a game that has no content rating, so fill it in if it's missing. |
| Who can play | Creator Dashboard → Odd Hours → Audience / Access | See step 4 |

## 4. Let your brothers and sisters in

Odd Hours belongs to the **Icey Labs** group, so the group decides who can play while the game isn't public.

1. Each sibling goes to the **Icey Labs** group page and asks to join.
2. You accept them: Creator Dashboard → switch to Icey Labs → Roles.
3. Put them in a role that has the **"Playtest experiences"** permission. Make a "Testers" role if you
   want one. That permission lets group members play the group's games before release.
4. If the game is already open to friends or to everyone, skip this step.

## 5. Get everyone into the same lobby

- Join the game first. Your siblings then use **Join** on your profile, or join from their friends list.
- Don't use a private (VIP) server. When a shift or training ends, the truck takes players back to a
  normal lobby, not to the private server.
- After training, you might come back to different lobbies. If that happens, use **Join** on each other's
  profile again.

## 6. What to test

Tick each one. If something breaks, write down what you did just before it went wrong.

1. **Training with two people.** Both of you walk to the Training pad at the same time. Each player gets
   their own training ride. Check that:
   - each of you finishes the training;
   - each of you gets the reward;
   - each of you comes back to the lobby;
   - the lobby no longer points you at the Training pad.
2. **Office shift with two people.** Both of you get on the same truck to the Office. Play the shift to
   the end and come back.
3. **School shift with two people.** Do the same thing with the School.
4. **Saving.** Look at your Gleam and anything you earned. Leave the game, wait 10 seconds, then join
   again. Everything should still be there.

## 7. Tester commands (only you can use them)

Only you (icemonkey1) can use these commands. Anyone else gets "You do not have permission".

To open the command box, press **F2** (or the **`** key, top left of the keyboard). Type the command,
then press Enter.

| Command | What it does |
|---|---|
| `trainingreset` | Makes **you** new to training again, tips included. Walk to the Training pad to play it again. Finishing it pays the reward again. |
| `trainingreset NAME` | Does the same for another player in your server. |
| `datawipe NAME` | Wipes that player's **whole save** back to a brand-new player's, then sends them out of the game. They join again to start fresh. **This can't be undone.** It only works on a player in your server. Use your own name to wipe yourself. |

To add another admin, the coordinator adds their Roblox user id to the admin list in the code.
