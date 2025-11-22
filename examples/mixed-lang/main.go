package main

import (
	"flag"
	"fmt"
	"math/rand"
	"time"
)

func main() {
	// Parse command line flags
	dataPoints := flag.Int("points", 1000, "Number of data points to generate")
	workers := flag.Int("workers", 4, "Number of worker goroutines")
	verbose := flag.Bool("verbose", false, "Verbose output")
	flag.Parse()

	logger := NewLogger("DataService")
	logger.Info("Starting data processing service")

	// Initialize metrics collector
	collector := NewMetricsCollector(10000)
	logger.Info("Metrics collector initialized with capacity 10000")

	// Generate sample data
	logger.Info("Generating %d data points", *dataPoints)
	datasets := generateSampleDatasets(5, *dataPoints)

	// Process data with workers
	logger.Info("Processing data with %d workers", *workers)
	processor := NewDataProcessor(*workers, 100)

	start := time.Now()
	results := processor.ProcessBatch(datasets)
	duration := time.Since(start)

	logger.Info("Batch processing completed in %v", duration)

	// Collect metrics from results
	for _, result := range results {
		if result.Error == "" {
			collector.AddMetric("processing_duration", result.Duration.Seconds(), nil)
			collector.AddMetric("output_count", float64(len(result.Output)), nil)

			if result.Stats != nil {
				collector.AddMetric("mean_value", result.Stats.Mean, nil)
				collector.AddMetric("max_value", result.Stats.Max, nil)
			}
		}
	}

	// Display summary
	fmt.Println("\n=== Processing Summary ===")
	fmt.Printf("Total datasets: %d\n", len(datasets))
	fmt.Printf("Successful: %d\n", countSuccessful(results))
	fmt.Printf("Total duration: %v\n", duration)
	fmt.Printf("Average per dataset: %v\n", duration/time.Duration(len(datasets)))

	// Display aggregate statistics
	metricNames := collector.GetAllMetricNames()
	if len(metricNames) > 0 {
		fmt.Println("\n=== Aggregate Statistics ===")
		for _, name := range metricNames {
			stats := collector.GetAggregates(name)
			if stats != nil {
				fmt.Printf("\n%s:\n", name)
				fmt.Printf("  Count: %d\n", stats.Count)
				fmt.Printf("  Mean: %.4f\n", stats.Mean)
				fmt.Printf("  Min: %.4f\n", stats.Min)
				fmt.Printf("  Max: %.4f\n", stats.Max)
				fmt.Printf("  StdDev: %.4f\n", stats.StdDev)
			}
		}
	}

	// Perform time series analysis on first result
	if len(results) > 0 && len(results[0].Output) > 0 {
		fmt.Println("\n=== Time Series Analysis ===")
		points := make([]DataPoint, len(results[0].Output))
		for i, v := range results[0].Output {
			points[i] = DataPoint{
				Timestamp: time.Now().Add(time.Duration(i) * time.Second),
				Value:     v,
			}
		}

		analyzer := NewTimeSeriesAnalyzer(points)
		trend := analyzer.DetectTrend()
		fmt.Printf("Detected trend: %s\n", trend)

		// Test seasonality detection
		seasonal := analyzer.DetectSeasonality(10)
		fmt.Printf("Seasonality (period=10): %v\n", seasonal)

		// Apply smoothing
		smoothed := analyzer.SmoothData(0.3)
		fmt.Printf("Smoothed data points: %d\n", len(smoothed))
	}

	// Detailed output if verbose
	if *verbose {
		fmt.Println("\n=== Detailed Results ===")
		for i, result := range results {
			if i >= 3 {
				fmt.Printf("\n... and %d more results\n", len(results)-i)
				break
			}
			fmt.Printf("\nDataset %d:\n", result.ID)
			fmt.Printf("  Input size: %d\n", len(result.Input))
			fmt.Printf("  Output size: %d\n", len(result.Output))
			fmt.Printf("  Duration: %v\n", result.Duration)
			if result.Stats != nil {
				fmt.Printf("  Mean: %.2f, StdDev: %.2f\n", result.Stats.Mean, result.Stats.StdDev)
			}
		}
	}

	logger.Info("Data processing service completed successfully")
}

// generateSampleDatasets creates multiple test datasets
func generateSampleDatasets(count, size int) [][]float64 {
	rand.Seed(time.Now().UnixNano())
	datasets := make([][]float64, count)

	for i := 0; i < count; i++ {
		dataset := make([]float64, size)
		for j := 0; j < size; j++ {
			// Generate values between -100 and 100
			dataset[j] = (rand.Float64()*200 - 100)
		}
		datasets[i] = dataset
	}

	return datasets
}

// countSuccessful counts results without errors
func countSuccessful(results []ProcessResult) int {
	count := 0
	for _, r := range results {
		if r.Error == "" {
			count++
		}
	}
	return count
}
