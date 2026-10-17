--!strict
--[=[
	OfficeDecorConstants: the office at night (Cleanup Crew spec §7 "emergency-exit glow, monitors glowing blue";
	"phones ringing in empty rooms, an elevator dinging on its own, typing that stops when you enter"). The decor's
	look and placement (OfficeDecorSystem builds it on the server) and the ambience emitters' tag and kinds (the
	client's OfficeAmbienceSystem plays from them). Positions are office-local studs (OfficeTypes). Static data
	(spec-exempt).

	@class OfficeDecorConstants
]=]

export type AmbientKind = "phone" | "typing" | "elevator"

return table.freeze({
	DECOR_FOLDER = "NightDecor",
	-- The invisible sound emitters: their tag, and the attribute naming what plays there.
	AMBIENT_TAG = "OfficeAmbient",
	AMBIENT_KIND_ATTRIBUTE = "AmbientKind",
	-- How far above a desk's top a phone or typing emitter sits; every TYPING_EVERY-th desk has a typist.
	EMITTER_LIFT = 0.5,
	TYPING_EVERY = 2,
	-- The elevator in reception (its west wall): the doors' centre, office-local (x, height, z).
	ELEVATOR_POINT = Vector3.new(0.6, 4, 45),
	ELEVATOR_DOOR_SIZE = Vector3.new(0.2, 8, 3),
	ELEVATOR_COLOR = Color3.fromRGB(150, 155, 162),
	ELEVATOR_LAMP_SIZE = Vector3.new(0.2, 0.6, 1.2),
	ELEVATOR_LAMP_COLOR = Color3.fromRGB(255, 176, 60),
	-- Exit signs over the doorways out of the loading bay.
	EXIT_SIGN_SIZE = Vector3.new(3, 1, 0.3),
	EXIT_SIGN_HEIGHT = 9,
	EXIT_COLOR = Color3.fromRGB(60, 235, 120),
	EXIT_LIGHT_RANGE = 11,
	EXIT_LIGHT_BRIGHTNESS = 1.1,
	-- A monitor on each desk: a dark case and a glowing blue screen.
	MONITOR_SIZE = Vector3.new(2, 1.3, 0.25),
	MONITOR_CASE_COLOR = Color3.fromRGB(30, 30, 34),
	MONITOR_COLOR = Color3.fromRGB(80, 140, 255),
	MONITOR_LIGHT_RANGE = 8,
	MONITOR_LIGHT_BRIGHTNESS = 0.75,
})
