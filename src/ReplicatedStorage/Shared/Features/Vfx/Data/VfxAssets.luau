--!strict
--[=[
	VfxAssets: the particle textures code-built bursts use (VfxBurstRegistry). Each is white on alpha, with grey
	shading inside the shape, so an emitter's ColorSequence tints it and the shading survives (toon shading on a
	puff, a facet on a shard). Made procedurally (characters/qa/vfx/textures/make_tex.py) and uploaded to the Icey Labs
	group; the values are the Image ids behind the uploaded Decals (the Decal ids are in
	characters/qa/vfx/vfx-audit.md).

	@class VfxAssets
]=]

return table.freeze({
	TEXTURES = table.freeze({
		-- A chunky toon cloud, lit from the top-left: dust, puffs, smoke.
		puff = "rbxassetid://139778349576683",
		-- A curling tendril: Gloom wisps.
		wisp = "rbxassetid://108650507314433",
		-- A chunky four-point sparkle with a soft halo.
		star = "rbxassetid://71271407323136",
		-- A two-facet fragment: porcelain shards, grime flakes.
		shard = "rbxassetid://109192738008496",
		-- A cartoon crack burst.
		crack = "rbxassetid://110313018734522",
		-- A paper slip with two printed lines and a folded corner.
		slip = "rbxassetid://118834476853565",
		-- A coin with a rim, an embossed sparkle and a highlight.
		coin = "rbxassetid://96086994928578",
		-- A soft ring for a pop.
		ring = "rbxassetid://98059630359923",
		-- A shine bar for the clean sweep.
		streak = "rbxassetid://140215498885808",
	}),
})
