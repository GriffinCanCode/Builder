package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"sort"
	"sync"
	"time"
)

// DataPoint represents a single data measurement
type DataPoint struct {
	Timestamp time.Time         `json:"timestamp"`
	Value     float64           `json:"value"`
	Tags      map[string]string `json:"tags"`
}

// MetricsCollector handles metric collection and aggregation
type MetricsCollector struct {
	mu         sync.RWMutex
	metrics    map[string][]DataPoint
	aggregates map[string]*AggregateStats
	maxPoints  int
}

// AggregateStats holds aggregated statistics
type AggregateStats struct {
	Count    int     `json:"count"`
	Sum      float64 `json:"sum"`
	Mean     float64 `json:"mean"`
	Min      float64 `json:"min"`
	Max      float64 `json:"max"`
	StdDev   float64 `json:"stddev"`
	Variance float64 `json:"variance"`
}

// NewMetricsCollector creates a new metrics collector
func NewMetricsCollector(maxPoints int) *MetricsCollector {
	return &MetricsCollector{
		metrics:    make(map[string][]DataPoint),
		aggregates: make(map[string]*AggregateStats),
		maxPoints:  maxPoints,
	}
}

// AddMetric adds a new metric data point
func (mc *MetricsCollector) AddMetric(name string, value float64, tags map[string]string) {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	point := DataPoint{
		Timestamp: time.Now(),
		Value:     value,
		Tags:      tags,
	}

	if _, exists := mc.metrics[name]; !exists {
		mc.metrics[name] = make([]DataPoint, 0, mc.maxPoints)
	}

	mc.metrics[name] = append(mc.metrics[name], point)

	// Trim if exceeds max points
	if len(mc.metrics[name]) > mc.maxPoints {
		mc.metrics[name] = mc.metrics[name][1:]
	}

	// Update aggregates
	mc.updateAggregates(name)
}

// updateAggregates recalculates aggregate statistics
func (mc *MetricsCollector) updateAggregates(name string) {
	points := mc.metrics[name]
	if len(points) == 0 {
		return
	}

	values := make([]float64, len(points))
	for i, p := range points {
		values[i] = p.Value
	}

	stats := calculateStats(values)
	mc.aggregates[name] = stats
}

// GetMetrics retrieves all metrics for a given name
func (mc *MetricsCollector) GetMetrics(name string) []DataPoint {
	mc.mu.RLock()
	defer mc.mu.RUnlock()

	if points, exists := mc.metrics[name]; exists {
		result := make([]DataPoint, len(points))
		copy(result, points)
		return result
	}

	return []DataPoint{}
}

// GetAggregates returns aggregated statistics
func (mc *MetricsCollector) GetAggregates(name string) *AggregateStats {
	mc.mu.RLock()
	defer mc.mu.RUnlock()

	if stats, exists := mc.aggregates[name]; exists {
		return stats
	}

	return nil
}

// GetAllMetricNames returns all registered metric names
func (mc *MetricsCollector) GetAllMetricNames() []string {
	mc.mu.RLock()
	defer mc.mu.RUnlock()

	names := make([]string, 0, len(mc.metrics))
	for name := range mc.metrics {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// Clear removes all metrics
func (mc *MetricsCollector) Clear() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	mc.metrics = make(map[string][]DataPoint)
	mc.aggregates = make(map[string]*AggregateStats)
}

// calculateStats computes statistical measures
func calculateStats(values []float64) *AggregateStats {
	if len(values) == 0 {
		return &AggregateStats{}
	}

	stats := &AggregateStats{
		Count: len(values),
		Min:   values[0],
		Max:   values[0],
	}

	sum := 0.0
	for _, v := range values {
		sum += v
		if v < stats.Min {
			stats.Min = v
		}
		if v > stats.Max {
			stats.Max = v
		}
	}

	stats.Sum = sum
	stats.Mean = sum / float64(len(values))

	// Calculate variance and standard deviation
	if len(values) > 1 {
		variance := 0.0
		for _, v := range values {
			diff := v - stats.Mean
			variance += diff * diff
		}
		variance /= float64(len(values) - 1)
		stats.Variance = variance
		stats.StdDev = math.Sqrt(variance)
	}

	return stats
}

// TimeSeriesAnalyzer provides time series analysis
type TimeSeriesAnalyzer struct {
	data []DataPoint
}

// NewTimeSeriesAnalyzer creates a new analyzer
func NewTimeSeriesAnalyzer(data []DataPoint) *TimeSeriesAnalyzer {
	return &TimeSeriesAnalyzer{data: data}
}

// DetectTrend identifies the overall trend
func (tsa *TimeSeriesAnalyzer) DetectTrend() string {
	if len(tsa.data) < 2 {
		return "insufficient_data"
	}

	firstHalf := tsa.data[:len(tsa.data)/2]
	secondHalf := tsa.data[len(tsa.data)/2:]

	firstAvg := average(extractValues(firstHalf))
	secondAvg := average(extractValues(secondHalf))

	diff := secondAvg - firstAvg
	threshold := 0.01

	if math.Abs(diff) < threshold {
		return "stable"
	} else if diff > 0 {
		return "increasing"
	}
	return "decreasing"
}

// DetectSeasonality checks for periodic patterns
func (tsa *TimeSeriesAnalyzer) DetectSeasonality(period int) bool {
	if len(tsa.data) < period*2 {
		return false
	}

	values := extractValues(tsa.data)
	correlations := make([]float64, 0)

	for lag := 1; lag <= period; lag++ {
		corr := calculateAutocorrelation(values, lag)
		correlations = append(correlations, corr)
	}

	// Check for significant autocorrelation at period
	if period <= len(correlations) {
		return correlations[period-1] > 0.5
	}

	return false
}

// SmoothData applies exponential smoothing
func (tsa *TimeSeriesAnalyzer) SmoothData(alpha float64) []DataPoint {
	if len(tsa.data) == 0 || alpha <= 0 || alpha > 1 {
		return tsa.data
	}

	smoothed := make([]DataPoint, len(tsa.data))
	smoothed[0] = tsa.data[0]

	for i := 1; i < len(tsa.data); i++ {
		smoothed[i] = tsa.data[i]
		smoothed[i].Value = alpha*tsa.data[i].Value + (1-alpha)*smoothed[i-1].Value
	}

	return smoothed
}

// calculateAutocorrelation computes autocorrelation at given lag
func calculateAutocorrelation(values []float64, lag int) float64 {
	if lag >= len(values) {
		return 0.0
	}

	mean := average(values)

	var numerator, denominator float64
	n := len(values) - lag

	for i := 0; i < n; i++ {
		numerator += (values[i] - mean) * (values[i+lag] - mean)
	}

	for _, v := range values {
		denominator += (v - mean) * (v - mean)
	}

	if denominator == 0 {
		return 0.0
	}

	return numerator / denominator
}

// DataProcessor handles complex data processing operations
type DataProcessor struct {
	workers   int
	batchSize int
	wg        sync.WaitGroup
	mu        sync.Mutex
	results   []ProcessResult
}

// ProcessResult holds processing results
type ProcessResult struct {
	ID       int                    `json:"id"`
	Input    []float64              `json:"input"`
	Output   []float64              `json:"output"`
	Stats    *AggregateStats        `json:"stats"`
	Metadata map[string]interface{} `json:"metadata"`
	Duration time.Duration          `json:"duration"`
	Error    string                 `json:"error,omitempty"`
}

// NewDataProcessor creates a new processor
func NewDataProcessor(workers, batchSize int) *DataProcessor {
	return &DataProcessor{
		workers:   workers,
		batchSize: batchSize,
		results:   make([]ProcessResult, 0),
	}
}

// ProcessBatch processes multiple datasets concurrently
func (dp *DataProcessor) ProcessBatch(datasets [][]float64) []ProcessResult {
	jobs := make(chan Job, len(datasets))
	results := make(chan ProcessResult, len(datasets))

	// Start workers
	for w := 0; w < dp.workers; w++ {
		dp.wg.Add(1)
		go dp.worker(jobs, results)
	}

	// Send jobs
	for id, data := range datasets {
		jobs <- Job{ID: id, Data: data}
	}
	close(jobs)

	// Collect results
	go func() {
		dp.wg.Wait()
		close(results)
	}()

	allResults := make([]ProcessResult, 0, len(datasets))
	for result := range results {
		allResults = append(allResults, result)
	}

	dp.mu.Lock()
	dp.results = append(dp.results, allResults...)
	dp.mu.Unlock()

	return allResults
}

// Job represents a processing job
type Job struct {
	ID   int
	Data []float64
}

// worker processes jobs from the queue
func (dp *DataProcessor) worker(jobs <-chan Job, results chan<- ProcessResult) {
	defer dp.wg.Done()

	for job := range jobs {
		start := time.Now()

		result := ProcessResult{
			ID:       job.ID,
			Input:    job.Data,
			Metadata: make(map[string]interface{}),
		}

		// Process the data
		processed := processDataset(job.Data)
		result.Output = processed
		result.Stats = calculateStats(processed)
		result.Duration = time.Since(start)
		result.Metadata["processed_count"] = len(processed)
		result.Metadata["reduction_ratio"] = float64(len(processed)) / float64(len(job.Data))

		results <- result
	}
}

// processDataset applies transformations to a dataset
func processDataset(data []float64) []float64 {
	if len(data) == 0 {
		return data
	}

	// Filter positive values
	filtered := make([]float64, 0)
	for _, v := range data {
		if v > 0 {
			filtered = append(filtered, v)
		}
	}

	// Apply transformation
	result := make([]float64, len(filtered))
	for i, v := range filtered {
		result[i] = v * 2
	}

	return result
}

// extractValues extracts float values from data points
func extractValues(points []DataPoint) []float64 {
	values := make([]float64, len(points))
	for i, p := range points {
		values[i] = p.Value
	}
	return values
}

// average calculates the mean of values
func average(values []float64) float64 {
	if len(values) == 0 {
		return 0
	}

	sum := 0.0
	for _, v := range values {
		sum += v
	}
	return sum / float64(len(values))
}

// ExportJSON exports data to JSON format
func ExportJSON(data interface{}) (string, error) {
	bytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// Logger provides structured logging
type Logger struct {
	prefix string
	level  string
}

// NewLogger creates a new logger
func NewLogger(prefix string) *Logger {
	return &Logger{prefix: prefix, level: "INFO"}
}

// Info logs an info message
func (l *Logger) Info(message string, args ...interface{}) {
	log.Printf("[%s] INFO: %s\n", l.prefix, fmt.Sprintf(message, args...))
}

// Error logs an error message
func (l *Logger) Error(message string, args ...interface{}) {
	log.Printf("[%s] ERROR: %s\n", l.prefix, fmt.Sprintf(message, args...))
}

// Debug logs a debug message
func (l *Logger) Debug(message string, args ...interface{}) {
	log.Printf("[%s] DEBUG: %s\n", l.prefix, fmt.Sprintf(message, args...))
}
