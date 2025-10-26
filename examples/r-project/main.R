#!/usr/bin/env Rscript

# R Data Analysis Example
# Demonstrates R script support in Builder

# Load required packages (Builder will detect these)
library(stats)

# Source helper functions
source("utils.R")

# Main analysis function
main <- function() {
    cat("R Data Analysis Tool\n")
    cat("====================\n\n")
    
    # Generate sample data
    set.seed(42)
    data <- rnorm(100, mean = 50, sd = 10)
    
    # Perform analysis
    cat("Dataset Statistics:\n")
    cat(sprintf("  Mean: %.2f\n", mean(data)))
    cat(sprintf("  Median: %.2f\n", median(data)))
    cat(sprintf("  SD: %.2f\n", sd(data)))
    cat(sprintf("  Min: %.2f\n", min(data)))
    cat(sprintf("  Max: %.2f\n", max(data)))
    cat("\n")
    
    # Use utility function
    result <- calculate_summary(data)
    cat("Summary Statistics:\n")
    print(result)
    
    cat("\n✓ Analysis completed successfully!\n")
    
    return(0)
}

# Run main if script is executed directly
if (sys.nframe() == 0) {
    status <- main()
    quit(status = status)
}

