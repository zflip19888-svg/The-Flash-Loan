/**
 * @file logger.ts
 * @notice Structured JSON logger with level filtering.
 *
 * Log levels (ascending severity): debug < info < warn < error
 * Set LOG_LEVEL in .env to control verbosity (default: info).
 */

type LogLevel = "debug" | "info" | "warn" | "error";

const LEVELS: Record<LogLevel, number> = {
  debug: 0,
  info:  1,
  warn:  2,
  error: 3,
};

function currentLevel(): LogLevel {
  const env = (process.env.LOG_LEVEL ?? "info").toLowerCase() as LogLevel;
  return LEVELS[env] !== undefined ? env : "info";
}

function shouldLog(level: LogLevel): boolean {
  return LEVELS[level] >= LEVELS[currentLevel()];
}

function log(level: LogLevel, message: string, meta?: unknown, extra?: unknown): void {
  if (!shouldLog(level)) return;

  const entry: Record<string, unknown> = {
    ts:      new Date().toISOString(),
    level,
    message,
  };

  if (meta !== undefined && meta !== null) {
    if (meta instanceof Error) {
      entry.error = { message: meta.message, stack: meta.stack };
    } else if (typeof meta === "object") {
      Object.assign(entry, meta);
    } else {
      entry.meta = meta;
    }
  }

  if (extra !== undefined) {
    if (typeof extra === "object" && extra !== null) {
      Object.assign(entry, extra);
    } else {
      entry.extra = extra;
    }
  }

  const line = JSON.stringify(entry);
  if (level === "error") {
    process.stderr.write(line + "\n");
  } else {
    process.stdout.write(line + "\n");
  }
}

export function logDebug(message: string, meta?: unknown): void {
  log("debug", message, meta);
}

export function logInfo(message: string, meta?: unknown): void {
  log("info", message, meta);
}

export function logWarn(message: string, meta?: unknown): void {
  log("warn", message, meta);
}

export function logError(message: string, err?: unknown, meta?: unknown): void {
  log("error", message, err instanceof Error ? err : undefined, meta);
}
