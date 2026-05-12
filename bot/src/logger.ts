/**
 * @file logger.ts
 * @notice Winston logger with daily rotating log files.
 *         Outputs to:
 *           bot/logs/combined-YYYY-MM-DD.log  — all levels
 *           bot/logs/error-YYYY-MM-DD.log     — error level only
 *           console                           — colourised during development
 */

import winston from "winston";
import DailyRotateFile from "winston-daily-rotate-file";
import path from "path";

const LOG_DIR = path.resolve(__dirname, "..", "logs");

// ─────────────────────────────────────────────────────────────────────────────
// Custom log format
// ─────────────────────────────────────────────────────────────────────────────

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss.SSS" }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : "";
    return stack
      ? `[${timestamp}] ${level.toUpperCase()}: ${message}\n${stack}${metaStr}`
      : `[${timestamp}] ${level.toUpperCase()}: ${message}${metaStr}`;
  })
);

const consoleFormat = winston.format.combine(
  winston.format.colorize({ all: true }),
  winston.format.timestamp({ format: "HH:mm:ss.SSS" }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : "";
    return `[${timestamp}] ${level}: ${message}${metaStr}`;
  })
);

// ─────────────────────────────────────────────────────────────────────────────
// Transports
// ─────────────────────────────────────────────────────────────────────────────

const combinedTransport = new DailyRotateFile({
  dirname:       LOG_DIR,
  filename:      "combined-%DATE%.log",
  datePattern:   "YYYY-MM-DD",
  maxFiles:      "30d",   // keep 30 days of combined logs
  maxSize:       "50m",
  level:         "info",
  format:        logFormat,
  zippedArchive: true,
});

const errorTransport = new DailyRotateFile({
  dirname:       LOG_DIR,
  filename:      "error-%DATE%.log",
  datePattern:   "YYYY-MM-DD",
  maxFiles:      "90d",   // keep error logs longer
  maxSize:       "20m",
  level:         "error",
  format:        logFormat,
  zippedArchive: true,
});

const consoleTransport = new winston.transports.Console({
  level:  process.env.LOG_LEVEL ?? "info",
  format: consoleFormat,
});

// ─────────────────────────────────────────────────────────────────────────────
// Logger instance
// ─────────────────────────────────────────────────────────────────────────────

const logger = winston.createLogger({
  level:       process.env.LOG_LEVEL ?? "info",
  transports:  [combinedTransport, errorTransport, consoleTransport],
  exitOnError: false,
});

// ─────────────────────────────────────────────────────────────────────────────
// Convenience helpers (typed wrappers)
// ─────────────────────────────────────────────────────────────────────────────

export function logInfo(message: string, meta?: Record<string, unknown>): void {
  logger.info(message, meta);
}

export function logWarn(message: string, meta?: Record<string, unknown>): void {
  logger.warn(message, meta);
}

export function logError(message: string, error?: unknown, meta?: Record<string, unknown>): void {
  if (error instanceof Error) {
    logger.error(message, { ...meta, error: error.message, stack: error.stack });
  } else {
    logger.error(message, { ...meta, error });
  }
}

export function logDebug(message: string, meta?: Record<string, unknown>): void {
  logger.debug(message, meta);
}

export default logger;
