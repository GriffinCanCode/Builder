#!/usr/bin/env Rscript

# Simple tests for utils.R

source("utils.R")

cat("Running R utility tests...\n\n")

# Test calculate_summary
test_calculate_summary <- function() {
    cat("Testing calculate_summary()... ")
    data <- c(1, 2, 3, 4, 5)
    result <- calculate_summary(data)
    
    stopifnot(result$count == 5)
    stopifnot(result$mean == 3)
    stopifnot(result$median == 3)
    
    cat("✓ PASSED\n")
}

# Test normalize
test_normalize <- function() {
    cat("Testing normalize()... ")
    data <- c(0, 5, 10)
    result <- normalize(data)
    
    stopifnot(result[1] == 0)
    stopifnot(result[3] == 1)
    stopifnot(all(result >= 0 & result <= 1))
    
    cat("✓ PASSED\n")
}

# Test standardize
test_standardize <- function() {
    cat("Testing standardize()... ")
    data <- c(10, 20, 30)
    result <- standardize(data)
    
    # Mean of z-scores should be ~0
    stopifnot(abs(mean(result)) < 1e-10)
    
    cat("✓ PASSED\n")
}

# Test validate_data
test_validate_data <- function() {
    cat("Testing validate_data()... ")
    
    # Valid data
    stopifnot(validate_data(c(1, 2, 3)))
    
    # Invalid data (should error)
    tryCatch({
        validate_data(c())
        stop("Should have failed on empty data")
    }, error = function(e) {
        # Expected
    })
    
    cat("✓ PASSED\n")
}

# Run all tests
test_calculate_summary()
test_normalize()
test_standardize()
test_validate_data()

cat("\n✓ All tests passed!\n")

