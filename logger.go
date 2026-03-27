package main

import (
	"log/slog"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// jsonLogger writes structured JSON to stdout. Docker captures stdout
// automatically, so no direct coupling to Loki is needed — Promtail
// handles shipping from Docker to Loki.
var jsonLogger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
	Level: slog.LevelInfo,
}))

// LoggingMiddleware emits one structured JSON log line per request after
// the handler completes, so that the final status code is known.
//
// Fields emitted:
//   - method:     HTTP verb (GET, POST, …)
//   - path:       raw request path (/alice)
//   - route:      Gin route template (/:username) — avoids high-cardinality
//     log labels, consistent with how PrometheusMiddleware labels metrics
//   - status:     HTTP response status code
//   - latency_ms: request duration in milliseconds
//   - client_ip:  originating IP (respects X-Forwarded-For via Gin)
//   - user_agent: browser / client identifier
//   - bytes_out:  response body size in bytes (-1 if nothing written)
func LoggingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next() // execute handler and all inner middleware

		route := c.FullPath()
		if route == "" {
			route = "unmatched"
		}

		jsonLogger.Info("request",
			slog.String("method", c.Request.Method),
			slog.String("path", c.Request.URL.Path),
			slog.String("route", route),
			slog.Int("status", c.Writer.Status()),
			slog.Int64("latency_ms", time.Since(start).Milliseconds()),
			slog.String("client_ip", c.ClientIP()),
			slog.String("user_agent", c.Request.UserAgent()),
			slog.Int("bytes_out", c.Writer.Size()),
		)
	}
}
