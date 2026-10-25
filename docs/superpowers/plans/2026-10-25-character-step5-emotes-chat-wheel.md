# Character step 5: emotes, stickers, pings (2026-10-25)

Design: docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md (§1, §8, step 5). Concepts: Figma
"Character UI" round 3 frames 7 (Chat wheel) and 9 (Emotes), characters/ui/character-ui/frames3.

## Owner's answers (25 Oct)
- Emotes have their own wheel: **hold B** (a button on phones), the current employee's 4 slots. **T** is the chat
  wheel (pings + stickers), as drawn.
- Emotes work **everywhere, shifts included** (the concept's "not during a shift" line goes).
- **The owner supplies the emote clips.** This step builds the system with registry slots; an emote with no clip
  yet shows "Coming soon" and does not play.
- Sticker art: GPT sheets (one per pack), cut out with the ink outline, shown before any upload (Icey Labs).

## My calls (check these)
1. Emote rules (server): the emote must be on the current employee's wheel (so owned and theirs); the body must be
   alive, not knocked down, not hiding, not carrying; one emote per 1.5 s. Moving, jumping, vacuuming or getting
   hit stops it (the client asks; the server also stops it when a knockdown/hide starts).
2. Emotes make no noise for the Manager (like stickers); revisit if shifts feel too safe.
3. Callouts (pings, stickers) go to everyone on the server: a shift server holds only its crew, and in the depot
   everyone is close by. Pings show for 6 s at a spot you aim at (max 150 studs), stickers 2.5 s over your head and in
   the crew list. Rate limit: 1 callout per 1 s, 5 per 10 s.
4. Ping icons reuse kit renders (gloom, gleamPile, managerHunt, grab, truck, a check) until owner asks otherwise.
5. Pings play one small UI sound (existing kit sound) for everyone on the server; stickers are silent.

## New modules
| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Animation | shared | Data | AnimationEmoteRegistry | the emote clips (empty until the owner supplies them), keyed `emote:<item id>` |
| Emote | shared | Data | EmoteConstants | cooldown, wheel slots, input action ids and keys |
| Emote | shared | Net | EmoteEvents | PlayRequest {slot}, StopRequest |
| Emote | shared | Rules | EmoteRules | which clip a wheel slot plays and whether the body may emote now |
| Emote | shared | Rules | EmoteRequestRules | build/parse the request packets |
| Emote | server | (root) | EmoteServiceServer | checks requests, starts and stops the replicated emote |
| Emote | client | (root) | EmoteServiceClient | the B action, opening the wheel, stop on move |
| Callout | shared | Data | CalloutRegistry | the 6 pings (id, word, icon) |
| Callout | shared | Data | CalloutConstants | durations, ranges, rate limits, the T action |
| Callout | shared | Net | CalloutEvents | Request {kind, id/slot, at?}, Shown {userId, kind, id, at?} |
| Callout | shared | Rules | CalloutRules | whether a callout is allowed (owned sticker slot, ping range, rate) |
| Callout | shared | Rules | CalloutRequestRules | build/parse the packets |
| Callout | server | (root) | CalloutServiceServer | checks requests and tells every client |
| Callout | client | (root) | CalloutServiceClient | the T action, sends requests, shows what arrives |
| Callout | client | Systems | CalloutStickerSystem | a sticker popping over a character's head |
| Callout | client | Systems | CalloutPingSystem | a ping marker at a spot, with its sound |
| Callout | client | State | CalloutStore | each player's latest sticker (the crew list reads it) |
| Emote | client | State | EmoteWheelStore | the emote wheel's open flag and leaned-toward slot |
| Callout | client | Data | CalloutAssets | ping icons and sticker pictures by name (stand-ins until the sticker art) |
| Callout | client | State | CalloutWheelStore | the chat wheel's open flag, pick and aimed spot |
| UI | client | Screens/Emote | EmoteWheelViewModel / EmoteWheelScreen | the in-game emote wheel |
| UI | client | Screens/ChatWheel | ChatWheelViewModel / ChatWheelScreen / ChatWheelButtons | the in-game chat wheel, and the phone buttons |
| UI | client | Screens/Inventory | InventoryChatPanel | the Inventory's Chat wheel tab |

Built: the wheels' scenes are registered by their services (EmoteServiceClient / CalloutServiceClient) at init, so
no separate Scene modules (a screen calling back into its service would be a require cycle).

Inventory gains an **Emotes** page tab (cards, "Your wheel" slots, Put on slot N) and the **Chat wheel** tab (sticker
packs, 4 sticker slots, the pings shown). Equip changes already exist (`emote` wheel slot, `sticker` slot).

## Tasks
1. **Emote core** (shared + server): registry domain, rules + specs, EmoteServiceServer (+spec through its request
   seam), wired to AnimationServiceServer. Done = specs green; a granted emote with a stand-in clip plays for a
   second client (Studio, 2 players).
2. **Emote wheel + Emotes tab** (client): B action, wheel scene, stop on move; Inventory Emotes tab with slot
   assignment. Done = specs green, screens checked in Studio PC + phone.
3. **Callouts** (shared + server + client systems): pings and stickers end to end with placeholder sticker art.
   Done = specs green; ping and sticker seen by a second client.
4. **Chat wheel + tab + crew list** (client UI). Done = screens checked PC + phone.
5. **Sticker art**: GPT sheets → cut-outs → owner OK → upload → UIAssets. (Waits on the owner.)
