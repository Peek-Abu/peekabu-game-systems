--!strict
--[=[
	BankEvents: the ByteNet packet contract for moving items and currency between a character's bag and
	their bank.

	Phase 4 built the whole server-authoritative bank and left it unreachable — until this contract, the
	only callers of `depositItem`/`withdrawItem` were Cmdr admin commands. Follows `EquipmentEvents`,
	which is the pattern for a packet set: one shared namespace module both realms require.

	**Items are addressed by KIND OF THING, not by a tagged union.** `BankServiceServer` takes
	`{ uid: string } | { itemType: string }`, and the obvious wire shape for that is one packet with a
	discriminator field — which would then need validating, and could arrive malformed. Four packets
	instead (`DepositUnique`, `DepositStack`, and their withdraw twins), each carrying one bare string,
	so the server constructs the union itself and a malformed spec is not expressible. Same reasoning as
	`EquipItem` carrying no slot.

	**A stack packet moves the WHOLE holding**, every stack entry of that itemType at once, because that
	is what the server does (bank design Decision 4) — there is no quantity here and adding one is not a
	UI change. Currency is the opposite: it carries an amount, because `depositCurrency` takes one. A
	"deposit all" is the client sending the full balance rather than a fifth verb, so the server keeps
	exactly one currency-transfer path to reason about.

	Neither packet answers. The result arrives the way every other state change does — the server mutates
	the bank and inventory/currency slices, and charm-sync replicates them into `StateSyncClientStore.bank` and
	`StateSyncClientStore.inventory`, which the screen reads reactively. A response would be a second source of
	truth for the same state.

	Boot-timing note (the same trap `DebuggerEvents` and `EquipmentEvents` document): ByteNet's
	client-side namespace lookup uses `FindFirstChild`, so the per-namespace value must exist before the
	client defines it. The server creates it on require; the client `WaitForChild`s below.

	@class BankEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "BankEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local BankEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: the UID of a unique item to move. One instance, unambiguously.
			DepositUnique = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			WithdrawUnique = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- client -> server: the itemType of a stackable to move. Moves the WHOLE holding (see header).
			DepositStack = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			WithdrawStack = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- client -> server: currency, which DOES carry an amount. `uint32` covers CurrencyConstants'
			-- MAX_CURRENCY (1e9) with room to spare, and cannot encode a negative — so "withdraw -100 to
			-- deposit" is unrepresentable rather than caught by a guard.
			DepositCurrency = ByteNet.definePacket({
				value = ByteNet.struct({
					currency = ByteNet.string,
					amount = ByteNet.uint32,
				}),
				reliabilityType = "reliable",
			}),
			WithdrawCurrency = ByteNet.definePacket({
				value = ByteNet.struct({
					currency = ByteNet.string,
					amount = ByteNet.uint32,
				}),
				reliabilityType = "reliable",
			}),
		},
		-- Empty but present: `defineNamespace` types the closure return as the full `namespaceData`
		-- shape, and the runtime fills `structs` itself and defaults `queries`. No QUERIES here, because
		-- no packet answers (see the header).
		queries = {},
		structs = {},
	}
end)

return BankEvents
