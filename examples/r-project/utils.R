# Utility functions for R data analysis

#' Calculate comprehensive summary statistics
#' 
#' @param data Numeric vector
#' @return List with summary statistics
calculate_summary <- function(data) {
    list(
        count = length(data),
        mean = mean(data),
        median = median(data),
        sd = sd(data),
        min = min(data),
        max = max(data),
        q25 = quantile(data, 0.25),
        q75 = quantile(data, 0.75),
        iqr = IQR(data)
    )
}

#' Normalize data to 0-1 range
#' 
#' @param data Numeric vector
#' @return Normalized vector
normalize <- function(data) {
    (data - min(data)) / (max(data) - min(data))
}

#' Calculate z-scores
#' 
#' @param data Numeric vector
#' @return Z-scores
standardize <- function(data) {
    (data - mean(data)) / sd(data)
}

#' Simple data validation
#' 
#' @param data Numeric vector
#' @return TRUE if valid
validate_data <- function(data) {
    if (!is.numeric(data)) {
        stop("Data must be numeric")
    }
    
    if (any(is.na(data))) {
        warning("Data contains NA values")
    }
    
    if (length(data) == 0) {
        stop("Data is empty")
    }
    
    TRUE
}

