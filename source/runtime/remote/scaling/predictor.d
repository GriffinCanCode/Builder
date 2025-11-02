module runtime.remote.scaling.predictor;

/// Load predictor using exponential smoothing
/// 
/// Responsibility: Predict future load based on historical data
/// Algorithm: Exponential smoothing + linear regression for trend
/// Used by: WorkerPool for autoscaling decisions
struct LoadPredictor
{
    private float[] samples;
    private size_t maxSamples;
    private float alpha;
    private float smoothedValue;
    
    this(float alpha, size_t maxSamples) pure nothrow @safe @nogc
    {
        this.alpha = alpha;
        this.maxSamples = maxSamples;
        this.smoothedValue = 0.0f;
    }
    
    /// Add observation
    /// 
    /// Responsibility: Update prediction with new data point
    /// Algorithm: St = αXt + (1-α)St-1
    void observe(float value) @safe
    {
        // Exponential smoothing: St = αXt + (1-α)St-1
        if (samples.length == 0)
        {
            smoothedValue = value;
        }
        else
        {
            smoothedValue = alpha * value + (1.0f - alpha) * smoothedValue;
        }
        
        samples ~= value;
        
        // Keep window size bounded
        if (samples.length > maxSamples)
        {
            samples = samples[1 .. $];
        }
    }
    
    /// Get smoothed prediction
    /// 
    /// Responsibility: Return current load prediction
    /// Returns: Smoothed value (0.0 - 1.0 for utilization)
    float predict() const pure nothrow @safe @nogc
    {
        return smoothedValue;
    }
    
    /// Get trend (positive = increasing load)
    /// 
    /// Responsibility: Calculate load trend direction and magnitude
    /// Algorithm: Simple linear regression slope
    /// Returns: Slope (positive = increasing, negative = decreasing)
    float trend() const pure @safe
    {
        if (samples.length < 2)
            return 0.0f;
        
        // Simple linear regression for trend
        immutable n = samples.length;
        float sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        
        foreach (i, y; samples)
        {
            immutable x = cast(float)i;
            sumX += x;
            sumY += y;
            sumXY += x * y;
            sumX2 += x * x;
        }
        
        // Slope: β = (n∑xy - ∑x∑y) / (n∑x² - (∑x)²)
        immutable denominator = n * sumX2 - sumX * sumX;
        if (denominator < 0.001f)
            return 0.0f;
        
        immutable slope = (n * sumXY - sumX * sumY) / denominator;
        return slope;
    }
}

