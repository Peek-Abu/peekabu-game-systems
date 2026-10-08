--!strict
--[=[
	Unit tests for DebuggerStore.

	`clientAtoms` is the one piece of real logic this module now carries: a `Charm.computed` whose
	getter reads every synced slice off `StateSyncClientStore` (via `StateSyncClientStore.readSlice`, which calls the
	underlying atom). Reading an atom inside a computed's getter registers it as a tracked dependency
	— this spec proves that wiring actually recomputes when a slice atom changes, which is exactly the
	staleness bug (Phase 3b manual testing: the client State tab went stale because the old
	`getClientAtoms()` read atoms imperatively, with no subscription) this module exists to fix.

	Runs under TestRunner.server.luau (a Script), where `Players.LocalPlayer` is always nil — there is
	no connected client in that context. `clientAtoms` tolerates that (falls back to userId 0) so this
	spec can exercise the real computed without a LocalPlayer seam; in the real client runtime,
	LocalPlayer is always present.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local DebuggerStore = require(script.Parent.DebuggerStore)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)

return function()
	describe("clientAtoms", function()
		afterEach(function()
			StateSyncClientStore.currency(nil) -- restore the loading-state default for other specs
		end)

		it("recomputes when a StateSyncClientStore slice changes", function()
			local before = DebuggerStore.clientAtoms()
			StateSyncClientStore.currency({ jaku = 42 })
			local after = DebuggerStore.clientAtoms()

			expect(after ~= before).to.equal(true) -- computed produced a fresh snapshot table

			local found = false
			for _, atom in after do
				if atom.slice == "currency" then
					found = atom.value ~= nil and (atom.value :: any).jaku == 42
				end
			end
			expect(found).to.equal(true)
		end)

		it("carries one entry per synced slice", function()
			local atoms = DebuggerStore.clientAtoms()
			expect(#atoms).to.equal(#StateSyncConstants.SLICES)
		end)
	end)
end
