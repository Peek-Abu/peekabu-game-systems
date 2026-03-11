--!strict
--[=[
	Logger: Centralized logging utility with log levels and optional service context.

	Usage:
		local Logger = require(path.to.Logger)
		local log = Logger.new("MyService")

		log:debug("Detailed info for debugging")
		log:info("General information")
		log:warn("Warning message")
		log:error("Error message")

	Log Levels (by numeric severity threshold):
		0 = DEBUG (most verbose)
		1 = INFO
		2 = WARN
		3 = ERROR
		4 = AUDIT
		5 = NONE (silent)

	@class Logger
]=]

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR" | "AUDIT" | "NONE"

export type Logger = {
	debug: (self: Logger, ...any) -> (),
	info: (self: Logger, ...any) -> (),
	warn: (self: Logger, ...any) -> (),
	error: (self: Logger, ...any) -> (),
	audit: (self: Logger, ...any) -> (),
	setLevel: (self: Logger, level: LogLevel) -> (),
}

--[=[
	A single recorded log line. Structured (level/context/message split out, not one formatted
	string) so consumers can filter and color by level or group by context without re-parsing.
	`clock` is `os.clock()` at record time — a monotonic seconds value; render age as `os.clock() - clock`.
]=]
export type LogEntry = {
	level: LogLevel,
	context: string, -- "" when the logger has no context name
	message: string,
	clock: number,
}

-- Maps each level to its numeric severity for threshold comparisons. Only ever accessed by key,
-- so the indexer type is the natural fit.
local LOG_LEVELS: { [LogLevel]: number } = {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	AUDIT = 4,
	NONE = 5,
}

local LOG_PREFIXES: { [LogLevel]: string } = {
	DEBUG = "[DEBUG]",
	INFO = "[INFO]",
	WARN = "[WARN]",
	ERROR = "[ERROR]",
	AUDIT = "[AUDIT]",
}

-- Console policy: everything is recorded into the ring buffer (the debug overlay's log panel is the
-- primary sink now), but only WARN/ERROR/AUDIT also reach the Roblox console — failures surface via
-- `warn`, and audit lines via `print` (an audit trail that only lived in a 200-entry in-memory ring
-- would evaporate on shutdown and never reach live-server output or CI logs). DEBUG/INFO stay
-- menu-only and don't flood the console. This is enforced structurally: only warn/error call `warn`
-- and only audit calls `print`.
--
-- Threshold semantics: AUDIT deliberately ranks ABOVE ERROR so a deployment can run audit-only
-- (`setGlobalLevel("AUDIT")` keeps the economy trail while silencing everything else — the
-- RequestHandler spec relies on exactly this). The flip side: audit-only mode also silences ERROR;
-- use WARN/ERROR as the threshold when you want both.

-- The real, emittable levels in severity order (excludes the NONE threshold sentinel). Exported via
-- getLevels() so UIs can build level filters without hard-coding the set — change the levels here and
-- the filters follow.
local EMITTED_LEVELS: { LogLevel } = { "DEBUG", "INFO", "WARN", "ERROR", "AUDIT" }

-- Global default log level (can be changed at runtime). Stored as the level itself; its numeric
-- severity is looked up via LOG_LEVELS only when comparing thresholds.
local globalLogLevel: LogLevel = "DEBUG"

--[=[
	Shared in-memory ring buffer of the most recent emitted log lines, across ALL logger instances.
	This is the seam the in-game debugger's log panel reads (and the future remote-telemetry hook can
	drain) — it captures structure the console `print`/`warn` throws away. Only lines that pass their
	level threshold are recorded, so the buffer matches what was actually emitted.

	Implemented as a fixed-capacity ring (head pointer, no front-shifting) so high-frequency logging
	never triggers O(n) table shuffles. `written` counts lifetime records; the live slot is
	`(written % CAPACITY) + 1`.
]=]
local HISTORY_CAPACITY = 200
local history: { LogEntry } = table.create(HISTORY_CAPACITY)
local written = 0
local subscribers: { (LogEntry) -> () } = {}

--[=[
	Records one emitted line into the ring buffer and notifies subscribers. Subscriber callbacks are
	pcall-isolated so a faulty listener can never break the logging path (and cannot recurse into the
	logger to report its own failure).
]=]
local function record(level: LogLevel, context: string, message: string)
	local entry: LogEntry = {
		level = level,
		context = context,
		message = message,
		clock = os.clock(),
	}
	written += 1
	history[(written - 1) % HISTORY_CAPACITY + 1] = entry

	for _, callback in subscribers do
		pcall(callback, entry)
	end
end

local LoggerModule = {}

--[=[
	Returns emitted log lines in chronological order (oldest first), newest-capped to the buffer
	capacity. Always a fresh array copy, so callers may hold or mutate it freely.
	@return { LogEntry } -- Chronological snapshot of the log history
]=]
function LoggerModule.getHistory(): { LogEntry }
	local count = math.min(written, HISTORY_CAPACITY)
	local result: { LogEntry } = table.create(count)
	-- When the ring has wrapped, the oldest surviving entry sits just after the live slot.
	local start = if written > HISTORY_CAPACITY then written % HISTORY_CAPACITY else 0
	for i = 1, count do
		result[i] = history[(start + i - 1) % HISTORY_CAPACITY + 1]
	end
	return result
end

--[=[
	Subscribes to every subsequently-recorded log line. Returns an unsubscribe function.
	@param callback (entry: LogEntry) -> () -- Invoked once per emitted line
	@return () -> () -- Call to stop receiving lines
]=]
function LoggerModule.subscribe(callback: (LogEntry) -> ()): () -> ()
	table.insert(subscribers, callback)
	return function()
		local index = table.find(subscribers, callback)
		if index then
			table.remove(subscribers, index)
		end
	end
end

--[=[
	Clears the recorded log history. Mainly for tests and the debugger's Clear button.
]=]
function LoggerModule.clearHistory()
	table.clear(history)
	written = 0
end

--[=[
	Returns the emittable log levels in severity order (DEBUG…AUDIT; excludes the NONE sentinel). UIs
	use this to build level filters without hard-coding the set.
	@return { LogLevel } -- Ordered copy of the emittable levels
]=]
function LoggerModule.getLevels(): { LogLevel }
	return table.clone(EMITTED_LEVELS)
end

--[=[
	Sets the global log level for all loggers.
	@param level LogLevel -- The minimum log level to display
]=]
function LoggerModule.setGlobalLevel(level: LogLevel)
	assert(LOG_LEVELS[level], `Invalid log level: {level}`)
	globalLogLevel = level
end

--[=[
	Gets the current global log level.
	@return LogLevel -- The current global log level
]=]
function LoggerModule.getGlobalLevel(): LogLevel
	return globalLogLevel
end

--[=[
	Creates a new logger instance with an optional context name.
	@param context string? -- Optional context name (e.g., service name)
	@return Logger -- A new logger instance
]=]
function LoggerModule.new(context: string?): Logger
	local self = {}
	local contextPrefix = context and `[{context}]` or ""
	local instanceLogLevel: LogLevel? = nil -- nil means use global

	local function shouldLog(level: LogLevel): boolean
		local threshold = LOG_LEVELS[instanceLogLevel or globalLogLevel]
		return LOG_LEVELS[level] >= threshold
	end

	-- Joins the variadic log args into one space-separated string. Split out from formatMessage so the
	-- ring buffer can store the raw message (no level/context prefix) without a second tostring pass.
	local function joinArgs(...: any): string
		local args = { ... }
		local parts = {}
		for _, arg in args do
			table.insert(parts, tostring(arg))
		end
		return table.concat(parts, " ")
	end

	local function formatMessage(level: LogLevel, message: string): string
		if contextPrefix ~= "" then
			return `{LOG_PREFIXES[level]} {contextPrefix} {message}`
		end
		return `{LOG_PREFIXES[level]} {message}`
	end

	-- The bare context name (no brackets) recorded alongside each entry, so the debugger can group by
	-- service. `contextPrefix` is the bracketed display form; this is the raw value.
	local contextName = context or ""

	--[=[
		Logs a debug message. Only shown when log level is DEBUG.
		@param ... any -- Values to log
	]=]
	function self.debug(_self: Logger, ...: any)
		if shouldLog("DEBUG") then
			record("DEBUG", contextName, joinArgs(...))
		end
	end

	--[=[
		Logs an info message. Shown when log level is INFO or lower.
		@param ... any -- Values to log
	]=]
	function self.info(_self: Logger, ...: any)
		if shouldLog("INFO") then
			record("INFO", contextName, joinArgs(...))
		end
	end

	--[=[
		Logs a warning message. Shown when log level is WARN or lower.
		@param ... any -- Values to log
	]=]
	function self.warn(_self: Logger, ...: any)
		if shouldLog("WARN") then
			local message = joinArgs(...)
			record("WARN", contextName, message)
			warn(formatMessage("WARN", message))
		end
	end

	--[=[
		Logs an error message. Shown when log level is ERROR or lower.

		NOTE: This uses `warn()` internally, NOT Luau's `error()`.
		Luau's `error()` throws and halts execution, which is inappropriate
		for logging—errors should be recorded without crashing the script.
		For intentional crashes, use `assert()` or `error()` directly.

		@param ... any -- Values to log
	]=]
	function self.error(_self: Logger, ...: any)
		if shouldLog("ERROR") then
			local message = joinArgs(...)
			record("ERROR", contextName, message)
			warn(formatMessage("ERROR", message))
		end
	end

	--[=[
		Logs an audit event. Used for permanent tracking (e.g. economy mutations). Audit lines are
		recorded in the ring buffer AND printed to the console, so they reach Roblox's log output /
		analytics rather than living only in the in-memory ring (see the console policy above).
		@param ... any -- Values to log
	]=]
	function self.audit(_self: Logger, ...: any)
		if shouldLog("AUDIT") then
			local message = joinArgs(...)
			record("AUDIT", contextName, message)
			print(formatMessage("AUDIT", message))
		end
	end

	--[=[
		Sets the log level for this specific logger instance.
		@param level LogLevel -- The minimum log level to display
	]=]
	function self.setLevel(_self: Logger, level: LogLevel)
		assert(LOG_LEVELS[level], `Invalid log level: {level}`)
		instanceLogLevel = level
	end

	return self
end

return LoggerModule
