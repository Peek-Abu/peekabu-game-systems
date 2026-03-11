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
	
	Log Levels (in order of severity):
		0 = DEBUG (most verbose)
		1 = INFO
		2 = WARN
		3 = ERROR
		4 = NONE (silent)
	
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

-- Global default log level (can be changed at runtime)
local globalLogLevel: number = LOG_LEVELS.DEBUG

local LoggerModule = {}

--[=[
	Sets the global log level for all loggers.
	@param level LogLevel -- The minimum log level to display
]=]
function LoggerModule.setGlobalLevel(level: LogLevel)
	assert(LOG_LEVELS[level], `Invalid log level: {level}`)
	globalLogLevel = LOG_LEVELS[level]
end

--[=[
	Gets the current global log level.
	@return LogLevel -- The current global log level
]=]
function LoggerModule.getGlobalLevel(): LogLevel
	for level, value in LOG_LEVELS do
		if value == globalLogLevel then
			return level
		end
	end
	return "INFO"
end

--[=[
	Creates a new logger instance with an optional context name.
	@param context string? -- Optional context name (e.g., service name)
	@return Logger -- A new logger instance
]=]
function LoggerModule.new(context: string?): Logger
	local self = {}
	local contextPrefix = context and `[{context}]` or ""
	local instanceLogLevel: number? = nil -- nil means use global

	local function shouldLog(level: LogLevel): boolean
		local threshold = instanceLogLevel or globalLogLevel
		return LOG_LEVELS[level] >= threshold
	end

	local function formatMessage(level: LogLevel, ...: any): string
		local args = { ... }
		local parts = {}
		for _, arg in args do
			table.insert(parts, tostring(arg))
		end
		local message = table.concat(parts, " ")

		if contextPrefix ~= "" then
			return `{LOG_PREFIXES[level]} {contextPrefix} {message}`
		end
		return `{LOG_PREFIXES[level]} {message}`
	end

	--[=[
		Logs a debug message. Only shown when log level is DEBUG.
		@param ... any -- Values to log
	]=]
	function self.debug(_self: Logger, ...: any)
		if shouldLog("DEBUG") then
			print(formatMessage("DEBUG", ...))
		end
	end

	--[=[
		Logs an info message. Shown when log level is INFO or lower.
		@param ... any -- Values to log
	]=]
	function self.info(_self: Logger, ...: any)
		if shouldLog("INFO") then
			print(formatMessage("INFO", ...))
		end
	end

	--[=[
		Logs a warning message. Shown when log level is WARN or lower.
		@param ... any -- Values to log
	]=]
	function self.warn(_self: Logger, ...: any)
		if shouldLog("WARN") then
			warn(formatMessage("WARN", ...))
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
			warn(formatMessage("ERROR", ...))
		end
	end

	--[=[
		Logs an audit event. Generally used for permanent tracking (e.g. economy mutations).
		@param ... any -- Values to log
	]=]
	function self.audit(_self: Logger, ...: any)
		if shouldLog("AUDIT") then
			print(formatMessage("AUDIT", ...))
			-- Setup remote logging HTTP calls here if desired!
		end
	end

	--[=[
		Sets the log level for this specific logger instance.
		@param level LogLevel -- The minimum log level to display
	]=]
	function self.setLevel(_self: Logger, level: LogLevel)
		assert(LOG_LEVELS[level], `Invalid log level: {level}`)
		instanceLogLevel = LOG_LEVELS[level]
	end

	return self :: Logger
end

return LoggerModule
