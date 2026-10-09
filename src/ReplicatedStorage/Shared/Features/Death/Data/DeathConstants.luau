--!strict
--[=[
	DeathConstants: the public field, the default config, ragdoll joint limits and the spectate actions.

	@class DeathConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)

local DEFAULT_CONFIG: DeathTypes.DeathConfig = {
	respawn = "auto",
	respawnDelay = 5,
	ragdoll = true,
	creditWindow = 10,
}

-- Per Motor6D name (R15 and R6); anything else uses DEFAULT_LIMITS.
local jointLimits: { [string]: DeathTypes.JointLimits } = {
	Neck = { upperAngle = 30, twistLower = -40, twistUpper = 40 },
	Waist = { upperAngle = 20, twistLower = -20, twistUpper = 20 },
	LeftShoulder = { upperAngle = 90, twistLower = -60, twistUpper = 60 },
	RightShoulder = { upperAngle = 90, twistLower = -60, twistUpper = 60 },
	["Left Shoulder"] = { upperAngle = 90, twistLower = -60, twistUpper = 60 },
	["Right Shoulder"] = { upperAngle = 90, twistLower = -60, twistUpper = 60 },
	LeftElbow = { upperAngle = 10, twistLower = 0, twistUpper = 120 },
	RightElbow = { upperAngle = 10, twistLower = 0, twistUpper = 120 },
	LeftWrist = { upperAngle = 20, twistLower = -30, twistUpper = 30 },
	RightWrist = { upperAngle = 20, twistLower = -30, twistUpper = 30 },
	LeftHip = { upperAngle = 50, twistLower = -20, twistUpper = 20 },
	RightHip = { upperAngle = 50, twistLower = -20, twistUpper = 20 },
	["Left Hip"] = { upperAngle = 50, twistLower = -20, twistUpper = 20 },
	["Right Hip"] = { upperAngle = 50, twistLower = -20, twistUpper = 20 },
	LeftKnee = { upperAngle = 10, twistLower = -120, twistUpper = 0 },
	RightKnee = { upperAngle = 10, twistLower = -120, twistUpper = 0 },
	LeftAnkle = { upperAngle = 20, twistLower = -20, twistUpper = 20 },
	RightAnkle = { upperAngle = 20, twistLower = -20, twistUpper = 20 },
}

local DEFAULT_LIMITS: DeathTypes.JointLimits = { upperAngle = 30, twistLower = -30, twistUpper = 30 }

local DeathConstants = {
	-- Public-player field set while a player is dead.
	PUBLIC_FIELD = "dead",
	DEFAULT_CONFIG = DEFAULT_CONFIG,
	JOINT_LIMITS = jointLimits,
	DEFAULT_LIMITS = DEFAULT_LIMITS,
	-- The root joint carries no ragdoll constraint (the root part follows the torso).
	ROOT_JOINT_NAMES = { "Root", "RootJoint" },
	-- Name given to the constraints and attachments a ragdoll adds.
	RAGDOLL_NAME = "Ragdoll",
	-- Spectate Input actions (DeathServiceClient registers them).
	SPECTATE_NEXT = "spectateNext",
	SPECTATE_PREV = "spectatePrev",
	-- Camera mode priority while spectating (above gameplay modes a game pushes at 0-10).
	SPECTATE_PRIORITY = 50,
}

return DeathConstants
