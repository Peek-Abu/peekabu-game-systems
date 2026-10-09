--!strict
--[=[
	LeaderstatServiceServer: keeps each player's `leaderstats` folder (Roblox's player list) in step with
	the registered columns (design: docs/superpowers/specs/2026-10-09-small-services-design.md).

	Every REFRESH_INTERVAL the service re-reads every column for every player; `refresh(player)` does it at
	once (call it right after a change the list should show immediately). A value object is created per
	column on first read (IntValue for whole numbers, NumberValue for other numbers, StringValue for
	strings) in registration order. The folder is display only; nothing reads it back.

	Spec-exempt shell (Instances, Players); the column catalogue is the specced LeaderstatRegistry.

	@class LeaderstatServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local LeaderstatRegistry = require(ServerScriptService.Features.Leaderstat.Data.LeaderstatRegistry)

local REFRESH_INTERVAL = 1
local FOLDER_NAME = "leaderstats"

local log = Logger.new("LeaderstatServiceServer")
local folders: { [Player]: Folder? } = {}
local stoppers: { () -> () } = {}
local running = false

local function valueObject(folder: Folder, name: string, value: number | string): ValueBase?
	local existing = folder:FindFirstChild(name)
	local wantClass = if type(value) == "string"
		then "StringValue"
		elseif value == math.floor(value) then "IntValue"
		else "NumberValue"
	if existing ~= nil and existing:IsA("ValueBase") and existing.ClassName == wantClass then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local created: ValueBase = if wantClass == "StringValue"
		then Instance.new("StringValue")
		elseif wantClass == "IntValue" then Instance.new("IntValue")
		else Instance.new("NumberValue")
	created.Name = name
	created.Parent = folder
	return created
end

local function writeValue(object: ValueBase, value: number | string)
	if type(value) == "string" then
		if object:IsA("StringValue") then
			object.Value = value
		end
	elseif object:IsA("IntValue") then
		object.Value = math.floor(value)
	elseif object:IsA("NumberValue") then
		object.Value = value
	end
end

local function refreshPlayer(player: Player)
	local folder = folders[player]
	if folder == nil then
		return
	end
	for _, name in LeaderstatRegistry.names() do
		local def = LeaderstatRegistry.get(name)
		if def ~= nil then
			local ok, value = pcall(def.read, player)
			if not ok then
				log:warn(`leaderstat "{name}" failed to read for {player.Name}: {value}`)
			elseif value ~= nil then
				local object = valueObject(folder, name, value)
				if object ~= nil then
					writeValue(object, value)
				end
			end
		end
	end
end

export type LeaderstatServiceServer = {
	dependencies: { string },
	start: (self: LeaderstatServiceServer) -> (),
	stop: (self: LeaderstatServiceServer) -> (),
	refresh: (self: LeaderstatServiceServer, player: Player) -> (),
	getState: (self: LeaderstatServiceServer) -> { [string]: any },
}

local LeaderstatServiceServer: LeaderstatServiceServer = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				-- Created only once there is a column: an empty folder still shows in the player list.
				if #LeaderstatRegistry.names() == 0 then
					return nil
				end
				local folder = Instance.new("Folder")
				folder.Name = FOLDER_NAME
				folder.Parent = player
				folders[player] = folder
				refreshPlayer(player)
				return function()
					folders[player] = nil
				end
			end)
		)
		running = true
		task.spawn(function()
			while running do
				task.wait(REFRESH_INTERVAL)
				for player in folders do
					refreshPlayer(player)
				end
			end
		end)
	end,

	stop = function(_self)
		running = false
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Re-reads every column for one player now.
	]=]
	refresh = function(_self, player)
		refreshPlayer(player)
	end,

	getState = function(_self)
		local players = 0
		for _ in folders do
			players += 1
		end
		return { columns = LeaderstatRegistry.names(), players = players }
	end,
}

return LeaderstatServiceServer
