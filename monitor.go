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
			Help:    "HTTP request duration in milliseconds",
			Buckets: []float64{0.1, 0.25, 0.5, 1, 2.5, 5, 10, 25, 50, 100, 250, 500, 1000}, // milliseconds
		},
		[]string{"method", "path"},
	)

	// Counts registration events. Useful to track growth over time.
	registrationsTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "minitwit_registrations_total",
		Help: "Total number of user registrations",
	})

	// Counts posted messages.
	messagesPostedTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "minitwit_messages_posted_total",
		Help: "Total number of messages posted",
	})
)

// PrometheusMiddleware records duration and request count for every route.
func PrometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next() // execute the actual handler

		duration := float64(time.Since(start).Microseconds() / 1000)
		status := strconv.Itoa(c.Writer.Status())

		// Use c.FullPath() instead of c.Request.URL.Path so that
		// /user/alice and /user/bob both map to /:username, not
		// creating unbounded label cardinality.
		path := c.FullPath()
		if path == "" {
			path = "unmatched"
		}

		// TODO: Implement big data hoarding with a swtitch case on the path for every route. Then PROFIT.
		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
	}
}
