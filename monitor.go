package main

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// Counts every HTTP request, labelled by method, path, and status code.
	// A Counter because request count only ever increases.
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "minitwit_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	// Tracks how long requests take, bucketed by duration.
	// A Histogram because you want to know the distribution (p50, p95, p99).
	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "minitwit_http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: []float64{0.01, 0.05, 0.25, 1, 5, 10}, // Seconds
		},
		[]string{"method", "path"},
	)
)

// PrometheusMiddleware records duration and request count for every route.
func PrometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next() // execute the actual handler

		duration := time.Since(start).Seconds()

		status := strconv.Itoa(c.Writer.Status())

		// Use c.FullPath() instead of c.Request.URL.Path so that
		// /user/alice and /user/bob both map to /:username, not
		// creating unbounded label cardinality.
		path := c.FullPath()
		if path == "" {
			path = "unmatched"
		}

		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
	}
}
