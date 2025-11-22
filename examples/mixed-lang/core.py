"""Core data processing library with extensive functionality."""
import json
import math
import statistics
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from collections import defaultdict, Counter

class DataProcessor:
    """Advanced data processing engine."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.cache = {}
        self.stats = defaultdict(int)
        self.history = []
        
    def process_data(self, data: List[float]) -> List[float]:
        """Process raw data with filtering and transformation."""
        self.stats['process_calls'] += 1
        result = [x * 2 for x in data if x > 0]
        self.history.append(('process', len(data), len(result)))
        return result
    
    def validate_data(self, data: List[Any]) -> bool:
        """Validate data format and constraints."""
        self.stats['validate_calls'] += 1
        if not isinstance(data, list):
            return False
        if not data:
            return True
        return all(isinstance(x, (int, float)) for x in data)
    
    def summarize_data(self, data: List[float]) -> Dict[str, Any]:
        """Generate comprehensive data summary."""
        self.stats['summarize_calls'] += 1
        if not data:
            return {
                'count': 0, 'sum': 0, 'avg': 0,
                'min': None, 'max': None,
                'median': None, 'stdev': None
            }
        
        return {
            'count': len(data),
            'sum': sum(data),
            'avg': statistics.mean(data),
            'min': min(data),
            'max': max(data),
            'median': statistics.median(data),
            'stdev': statistics.stdev(data) if len(data) > 1 else 0,
            'variance': statistics.variance(data) if len(data) > 1 else 0
        }
    
    def analyze_distribution(self, data: List[float]) -> Dict[str, Any]:
        """Analyze statistical distribution of data."""
        if not data:
            return {}
        
        sorted_data = sorted(data)
        n = len(sorted_data)
        
        return {
            'quartiles': {
                'q1': sorted_data[n // 4],
                'q2': sorted_data[n // 2],
                'q3': sorted_data[3 * n // 4]
            },
            'percentiles': {
                'p10': sorted_data[n // 10],
                'p25': sorted_data[n // 4],
                'p50': sorted_data[n // 2],
                'p75': sorted_data[3 * n // 4],
                'p90': sorted_data[9 * n // 10]
            },
            'range': max(data) - min(data),
            'iqr': sorted_data[3 * n // 4] - sorted_data[n // 4]
        }
    
    def detect_outliers(self, data: List[float], threshold: float = 2.0) -> List[Tuple[int, float]]:
        """Detect outliers using z-score method."""
        if len(data) < 2:
            return []
        
        mean = statistics.mean(data)
        stdev = statistics.stdev(data)
        
        outliers = []
        for idx, value in enumerate(data):
            z_score = abs((value - mean) / stdev) if stdev > 0 else 0
            if z_score > threshold:
                outliers.append((idx, value))
        
        return outliers
    
    def normalize_data(self, data: List[float]) -> List[float]:
        """Normalize data to 0-1 range."""
        if not data:
            return []
        
        min_val = min(data)
        max_val = max(data)
        range_val = max_val - min_val
        
        if range_val == 0:
            return [0.5] * len(data)
        
        return [(x - min_val) / range_val for x in data]
    
    def standardize_data(self, data: List[float]) -> List[float]:
        """Standardize data to mean=0, stdev=1."""
        if len(data) < 2:
            return [0.0] * len(data)
        
        mean = statistics.mean(data)
        stdev = statistics.stdev(data)
        
        if stdev == 0:
            return [0.0] * len(data)
        
        return [(x - mean) / stdev for x in data]
    
    def moving_average(self, data: List[float], window: int = 3) -> List[float]:
        """Calculate moving average with specified window."""
        if window < 1 or len(data) < window:
            return data.copy()
        
        result = []
        for i in range(len(data) - window + 1):
            window_data = data[i:i + window]
            result.append(sum(window_data) / window)
        
        return result
    
    def exponential_smoothing(self, data: List[float], alpha: float = 0.3) -> List[float]:
        """Apply exponential smoothing to data."""
        if not data or alpha <= 0 or alpha > 1:
            return data.copy()
        
        result = [data[0]]
        for i in range(1, len(data)):
            smoothed = alpha * data[i] + (1 - alpha) * result[-1]
            result.append(smoothed)
        
        return result
    
    def calculate_correlation(self, x: List[float], y: List[float]) -> float:
        """Calculate Pearson correlation coefficient."""
        if len(x) != len(y) or len(x) < 2:
            return 0.0
        
        return statistics.correlation(x, y)
    
    def linear_regression(self, x: List[float], y: List[float]) -> Tuple[float, float]:
        """Calculate linear regression slope and intercept."""
        if len(x) != len(y) or len(x) < 2:
            return (0.0, 0.0)
        
        n = len(x)
        x_mean = statistics.mean(x)
        y_mean = statistics.mean(y)
        
        numerator = sum((x[i] - x_mean) * (y[i] - y_mean) for i in range(n))
        denominator = sum((x[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            return (0.0, y_mean)
        
        slope = numerator / denominator
        intercept = y_mean - slope * x_mean
        
        return (slope, intercept)
    
    def get_statistics(self) -> Dict[str, int]:
        """Get processor statistics."""
        return dict(self.stats)
    
    def clear_cache(self):
        """Clear internal cache."""
        self.cache.clear()
        self.stats['cache_clears'] += 1
    
    def get_history(self) -> List[Tuple]:
        """Get operation history."""
        return self.history.copy()


class TimeSeries:
    """Time series data analysis."""
    
    def __init__(self, timestamps: List[datetime], values: List[float]):
        if len(timestamps) != len(values):
            raise ValueError("Timestamps and values must have same length")
        self.timestamps = timestamps
        self.values = values
    
    def resample(self, interval: timedelta) -> 'TimeSeries':
        """Resample time series to regular intervals."""
        if not self.timestamps:
            return TimeSeries([], [])
        
        start = self.timestamps[0]
        end = self.timestamps[-1]
        
        new_timestamps = []
        new_values = []
        current = start
        
        while current <= end:
            # Find values within interval
            interval_values = [
                v for t, v in zip(self.timestamps, self.values)
                if current <= t < current + interval
            ]
            
            if interval_values:
                new_timestamps.append(current)
                new_values.append(statistics.mean(interval_values))
            
            current += interval
        
        return TimeSeries(new_timestamps, new_values)
    
    def detect_trend(self) -> str:
        """Detect overall trend in time series."""
        if len(self.values) < 2:
            return 'insufficient_data'
        
        x = list(range(len(self.values)))
        processor = DataProcessor()
        slope, _ = processor.linear_regression(x, self.values)
        
        if abs(slope) < 0.01:
            return 'stable'
        elif slope > 0:
            return 'increasing'
        else:
            return 'decreasing'
    
    def calculate_volatility(self) -> float:
        """Calculate volatility (coefficient of variation)."""
        if not self.values or len(self.values) < 2:
            return 0.0
        
        mean = statistics.mean(self.values)
        stdev = statistics.stdev(self.values)
        
        return (stdev / mean) if mean != 0 else 0.0


def batch_process(datasets: List[List[float]]) -> List[Dict[str, Any]]:
    """Process multiple datasets in batch."""
    processor = DataProcessor()
    results = []
    
    for dataset in datasets:
        if processor.validate_data(dataset):
            processed = processor.process_data(dataset)
            summary = processor.summarize_data(processed)
            results.append(summary)
        else:
            results.append({'error': 'Invalid data format'})
    
    return results


def aggregate_results(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Aggregate results from multiple processing runs."""
    valid_results = [r for r in results if 'error' not in r]
    
    if not valid_results:
        return {'status': 'no_valid_results'}
    
    return {
        'total_datasets': len(results),
        'valid_datasets': len(valid_results),
        'total_count': sum(r.get('count', 0) for r in valid_results),
        'avg_sum': statistics.mean([r.get('sum', 0) for r in valid_results]),
        'avg_avg': statistics.mean([r.get('avg', 0) for r in valid_results])
    }
