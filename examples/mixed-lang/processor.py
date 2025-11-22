"""Data processor application with advanced features."""
import sys
import json
import argparse
from typing import List, Dict, Any, Optional
from datetime import datetime
from core import DataProcessor, TimeSeries, batch_process, aggregate_results


class Pipeline:
    """Data processing pipeline orchestrator."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.processor = DataProcessor(config)
        self.results = []
        self.errors = []
        
    def run(self, data: List[float], operations: List[str]) -> Dict[str, Any]:
        """Run pipeline with specified operations."""
        result = {'input_size': len(data), 'operations': []}
        current_data = data.copy()
        
        for op in operations:
            try:
                if op == 'process':
                    current_data = self.processor.process_data(current_data)
                    result['operations'].append({'op': op, 'output_size': len(current_data)})
                elif op == 'normalize':
                    current_data = self.processor.normalize_data(current_data)
                    result['operations'].append({'op': op, 'applied': True})
                elif op == 'standardize':
                    current_data = self.processor.standardize_data(current_data)
                    result['operations'].append({'op': op, 'applied': True})
                elif op == 'smooth':
                    current_data = self.processor.exponential_smoothing(current_data)
                    result['operations'].append({'op': op, 'applied': True})
                elif op == 'summarize':
                    summary = self.processor.summarize_data(current_data)
                    result['operations'].append({'op': op, 'summary': summary})
                else:
                    self.errors.append(f"Unknown operation: {op}")
            except Exception as e:
                self.errors.append(f"Error in {op}: {str(e)}")
        
        result['final_data'] = current_data
        result['errors'] = self.errors
        return result
    
    def validate_pipeline(self, operations: List[str]) -> bool:
        """Validate pipeline operations."""
        valid_ops = {'process', 'normalize', 'standardize', 'smooth', 'summarize', 'analyze'}
        return all(op in valid_ops for op in operations)
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get pipeline execution metrics."""
        return {
            'total_runs': len(self.results),
            'errors': len(self.errors),
            'processor_stats': self.processor.get_statistics()
        }


class DataSource:
    """Abstract data source for different input types."""
    
    def __init__(self, source_type: str, config: Dict[str, Any]):
        self.source_type = source_type
        self.config = config
        self.cache = {}
    
    def read_data(self) -> List[float]:
        """Read data from source."""
        if self.source_type == 'static':
            return self._read_static()
        elif self.source_type == 'generated':
            return self._read_generated()
        elif self.source_type == 'file':
            return self._read_file()
        else:
            return []
    
    def _read_static(self) -> List[float]:
        """Read static predefined data."""
        return self.config.get('data', [1, 2, 3, 4, 5])
    
    def _read_generated(self) -> List[float]:
        """Generate synthetic data."""
        import random
        count = self.config.get('count', 100)
        min_val = self.config.get('min', 0)
        max_val = self.config.get('max', 100)
        
        random.seed(self.config.get('seed', 42))
        return [random.uniform(min_val, max_val) for _ in range(count)]
    
    def _read_file(self) -> List[float]:
        """Read data from file."""
        filepath = self.config.get('path', 'data.json')
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                return data if isinstance(data, list) else []
        except:
            return []


class DataSink:
    """Data output handler."""
    
    def __init__(self, sink_type: str, config: Dict[str, Any]):
        self.sink_type = sink_type
        self.config = config
    
    def write_data(self, data: Any):
        """Write data to sink."""
        if self.sink_type == 'console':
            self._write_console(data)
        elif self.sink_type == 'file':
            self._write_file(data)
        elif self.sink_type == 'memory':
            self._write_memory(data)
    
    def _write_console(self, data: Any):
        """Write to console."""
        if isinstance(data, dict):
            print(json.dumps(data, indent=2))
        else:
            print(data)
    
    def _write_file(self, data: Any):
        """Write to file."""
        filepath = self.config.get('path', 'output.json')
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _write_memory(self, data: Any):
        """Store in memory."""
        if not hasattr(self, 'buffer'):
            self.buffer = []
        self.buffer.append(data)


class Application:
    """Main application controller."""
    
    def __init__(self):
        self.pipeline = None
        self.source = None
        self.sink = None
        self.config = {}
    
    def initialize(self, config: Dict[str, Any]):
        """Initialize application components."""
        self.config = config
        
        self.pipeline = Pipeline(config.get('pipeline', {}))
        
        source_config = config.get('source', {'type': 'static'})
        self.source = DataSource(source_config['type'], source_config)
        
        sink_config = config.get('sink', {'type': 'console'})
        self.sink = DataSink(sink_config['type'], sink_config)
    
    def run(self):
        """Run the application."""
        print("=== Builder Mixed-Language Example (Enhanced) ===\n")
        
        # Read input data
        raw_data = self.source.read_data()
        print(f"Input: {len(raw_data)} data points")
        print(f"Sample: {raw_data[:10]}...")
        
        # Process through pipeline
        operations = self.config.get('operations', ['process', 'summarize'])
        result = self.pipeline.run(raw_data, operations)
        
        # Write output
        print("\nPipeline Results:")
        for op_result in result.get('operations', []):
            print(f"  {op_result}")
        
        if 'errors' in result and result['errors']:
            print("\nErrors:")
            for error in result['errors']:
                print(f"  - {error}")
        
        # Get summary if available
        final_data = result.get('final_data', [])
        if final_data:
            processor = DataProcessor()
            summary = processor.summarize_data(final_data)
            
            print("\nFinal Data Summary:")
            for key, value in summary.items():
                print(f"  {key}: {value}")
            
            # Analyze distribution
            distribution = processor.analyze_distribution(final_data)
            if distribution:
                print("\nDistribution Analysis:")
                if 'quartiles' in distribution:
                    print(f"  Quartiles: {distribution['quartiles']}")
                if 'range' in distribution:
                    print(f"  Range: {distribution['range']}")
                if 'iqr' in distribution:
                    print(f"  IQR: {distribution['iqr']}")
            
            # Detect outliers
            outliers = processor.detect_outliers(final_data)
            if outliers:
                print(f"\nOutliers detected: {len(outliers)}")
                for idx, value in outliers[:5]:  # Show first 5
                    print(f"  Position {idx}: {value}")
        
        # Output metrics
        metrics = self.pipeline.get_metrics()
        print("\nPipeline Metrics:")
        for key, value in metrics.items():
            print(f"  {key}: {value}")
        
        self.sink.write_data(result)


def create_default_config() -> Dict[str, Any]:
    """Create default application configuration."""
    return {
        'pipeline': {'mode': 'standard'},
        'source': {
            'type': 'generated',
            'count': 500,
            'min': -100,
            'max': 100,
            'seed': 42
        },
        'sink': {'type': 'console'},
        'operations': ['process', 'normalize', 'smooth', 'summarize']
    }


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Data Processor Application')
    parser.add_argument('--config', type=str, help='Config file path')
    parser.add_argument('--count', type=int, default=500, help='Data point count')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    return parser.parse_args()


def main():
    """Main entry point."""
    args = parse_arguments()
    
    config = create_default_config()
    if args.config:
        try:
            with open(args.config, 'r') as f:
                custom_config = json.load(f)
                config.update(custom_config)
        except Exception as e:
            print(f"Warning: Could not load config file: {e}")
    
    if args.count:
        config['source']['count'] = args.count
    
    app = Application()
    app.initialize(config)
    app.run()


if __name__ == "__main__":
    main()
