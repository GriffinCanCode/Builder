/**
 * Web UI components and data visualization
 * Advanced dashboard with multiple chart types and real-time updates
 */

const EventEmitter = require('events');

class ChartRenderer {
    constructor(containerId, options = {}) {
        this.containerId = containerId;
        this.options = {
            width: options.width || 800,
            height: options.height || 600,
            theme: options.theme || 'light',
            animations: options.animations !== false
        };
        this.data = [];
        this.listeners = new Map();
    }

    setData(data) {
        this.data = data;
        this.render();
    }

    render() {
        console.log(`Rendering chart in ${this.containerId}:`, {
            dataPoints: this.data.length,
            dimensions: `${this.options.width}x${this.options.height}`,
            theme: this.options.theme
        });
        // In a real app, this would render to canvas/SVG
    }

    renderLineChart(datasets) {
        console.log('Line chart rendering:', {
            datasets: datasets.length,
            totalPoints: datasets.reduce((sum, d) => sum + d.data.length, 0)
        });
        
        datasets.forEach((dataset, idx) => {
            this._drawLine(dataset.data, dataset.color || this._getDefaultColor(idx));
        });
    }

    renderBarChart(categories, values) {
        console.log('Bar chart rendering:', {
            categories: categories.length,
            values: values.length
        });
        
        categories.forEach((category, idx) => {
            this._drawBar(category, values[idx], idx);
        });
    }

    renderScatterPlot(points) {
        console.log('Scatter plot rendering:', {
            points: points.length
        });
        
        points.forEach(point => {
            this._drawPoint(point.x, point.y, point.color, point.size);
        });
    }

    renderHeatmap(matrix) {
        const rows = matrix.length;
        const cols = matrix[0]?.length || 0;
        console.log('Heatmap rendering:', { rows, cols });
        
        for (let i = 0; i < rows; i++) {
            for (let j = 0; j < cols; j++) {
                this._drawCell(i, j, matrix[i][j]);
            }
        }
    }

    _drawLine(points, color) {
        // Simulate line drawing
        console.log(`Drawing line with ${points.length} points in ${color}`);
    }

    _drawBar(label, value, index) {
        console.log(`Drawing bar ${index}: ${label} = ${value}`);
    }

    _drawPoint(x, y, color, size) {
        // Simulate point drawing
    }

    _drawCell(row, col, value) {
        // Simulate heatmap cell drawing
    }

    _getDefaultColor(index) {
        const colors = ['#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6'];
        return colors[index % colors.length];
    }

    clear() {
        console.log(`Clearing chart: ${this.containerId}`);
        this.data = [];
    }

    destroy() {
        this.clear();
        this.listeners.clear();
    }
}

class Dashboard extends EventEmitter {
    constructor(config = {}) {
        super();
        this.config = config;
        this.widgets = new Map();
        this.charts = new Map();
        this.updateInterval = config.updateInterval || 5000;
        this.isActive = false;
    }

    initialize() {
        console.log('Initializing dashboard...');
        this._createLayout();
        this._setupWidgets();
        this._startAutoUpdate();
        this.isActive = true;
        this.emit('initialized');
    }

    _createLayout() {
        console.log('Creating dashboard layout');
        // Simulate layout creation
    }

    _setupWidgets() {
        const widgetConfigs = [
            { id: 'summary', type: 'stats', position: 'top-left' },
            { id: 'mainChart', type: 'line', position: 'center' },
            { id: 'distribution', type: 'bar', position: 'bottom-left' },
            { id: 'correlation', type: 'heatmap', position: 'right' }
        ];

        widgetConfigs.forEach(config => {
            this.addWidget(config.id, config.type, config.position);
        });
    }

    addWidget(id, type, position) {
        console.log(`Adding widget: ${id} (${type}) at ${position}`);
        this.widgets.set(id, { id, type, position, data: null });
        
        if (['line', 'bar', 'scatter', 'heatmap'].includes(type)) {
            const chart = new ChartRenderer(id, this.config.chartOptions);
            this.charts.set(id, chart);
        }
    }

    updateWidget(id, data) {
        const widget = this.widgets.get(id);
        if (!widget) {
            console.error(`Widget not found: ${id}`);
            return;
        }

        widget.data = data;
        console.log(`Updating widget ${id}:`, data);

        const chart = this.charts.get(id);
        if (chart) {
            chart.setData(data);
        }

        this.emit('widgetUpdated', { id, data });
    }

    updateDashboard(summary) {
        console.log('Dashboard data update:', summary);

        if (summary.count !== undefined) {
            this.updateWidget('summary', {
                count: summary.count,
                sum: summary.sum,
                avg: summary.avg,
                min: summary.min,
                max: summary.max
            });
        }

        if (summary.timeSeries) {
            const chart = this.charts.get('mainChart');
            if (chart) {
                chart.renderLineChart([{
                    data: summary.timeSeries,
                    color: '#3498db'
                }]);
            }
        }

        if (summary.distribution) {
            const chart = this.charts.get('distribution');
            if (chart) {
                chart.renderBarChart(
                    Object.keys(summary.distribution),
                    Object.values(summary.distribution)
                );
            }
        }

        this.emit('dashboardUpdated', summary);
    }

    _startAutoUpdate() {
        if (this.updateTimer) {
            clearInterval(this.updateTimer);
        }

        this.updateTimer = setInterval(() => {
            this._fetchAndUpdate();
        }, this.updateInterval);
    }

    _fetchAndUpdate() {
        // Simulate data fetching
        console.log('Auto-updating dashboard...');
        this.emit('autoUpdate');
    }

    stop() {
        if (this.updateTimer) {
            clearInterval(this.updateTimer);
            this.updateTimer = null;
        }
        this.isActive = false;
        this.emit('stopped');
    }

    destroy() {
        this.stop();
        this.charts.forEach(chart => chart.destroy());
        this.charts.clear();
        this.widgets.clear();
        this.removeAllListeners();
    }
}

class DataVisualization {
    constructor() {
        this.renderers = new Map();
        this.cache = new Map();
    }

    createVisualization(type, containerId, options) {
        const renderer = new ChartRenderer(containerId, options);
        this.renderers.set(containerId, renderer);
        return renderer;
    }

    renderMultiple(visualizations) {
        visualizations.forEach(viz => {
            const renderer = this.renderers.get(viz.containerId);
            if (renderer) {
                switch (viz.type) {
                    case 'line':
                        renderer.renderLineChart(viz.datasets);
                        break;
                    case 'bar':
                        renderer.renderBarChart(viz.categories, viz.values);
                        break;
                    case 'scatter':
                        renderer.renderScatterPlot(viz.points);
                        break;
                    case 'heatmap':
                        renderer.renderHeatmap(viz.matrix);
                        break;
                }
            }
        });
    }

    clearAll() {
        this.renderers.forEach(renderer => renderer.clear());
    }

    destroyAll() {
        this.renderers.forEach(renderer => renderer.destroy());
        this.renderers.clear();
        this.cache.clear();
    }
}

class APIClient {
    constructor(baseURL, options = {}) {
        this.baseURL = baseURL;
        this.options = options;
        this.cache = new Map();
        this.pendingRequests = new Map();
    }

    async fetchData(endpoint, params = {}) {
        const url = this._buildURL(endpoint, params);
        const cacheKey = url;

        if (this.cache.has(cacheKey)) {
            console.log(`Cache hit: ${cacheKey}`);
            return this.cache.get(cacheKey);
        }

        console.log(`Fetching: ${url}`);
        
        // Simulate API call
        return new Promise((resolve) => {
            setTimeout(() => {
                const mockData = this._generateMockData(endpoint);
                this.cache.set(cacheKey, mockData);
                resolve(mockData);
            }, 100);
        });
    }

    async postData(endpoint, data) {
        const url = `${this.baseURL}${endpoint}`;
        console.log(`Posting to: ${url}`, data);
        
        // Simulate API call
        return new Promise((resolve) => {
            setTimeout(() => {
                resolve({ success: true, data });
            }, 100);
        });
    }

    _buildURL(endpoint, params) {
        const url = `${this.baseURL}${endpoint}`;
        const queryString = Object.entries(params)
            .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
            .join('&');
        return queryString ? `${url}?${queryString}` : url;
    }

    _generateMockData(endpoint) {
        return {
            endpoint,
            timestamp: Date.now(),
            data: Array.from({ length: 100 }, (_, i) => ({
                id: i,
                value: Math.random() * 100
            }))
        };
    }

    clearCache() {
        this.cache.clear();
    }
}

module.exports = {
    ChartRenderer,
    Dashboard,
    DataVisualization,
    APIClient
};
