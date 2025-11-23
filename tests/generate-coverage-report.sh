#!/bin/bash
# Coverage Report Generator for Builder
# Converts D coverage .lst files to HTML reports

set -e

# Get the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

cd "${PROJECT_ROOT}"

# Create coverage directory
mkdir -p "${COVERAGE_DIR}"

# Find all .lst files
LST_FILES=$(find . -maxdepth 1 -name "*.lst" -type f)

if [ -z "$LST_FILES" ]; then
    echo "No coverage files found"
    exit 0
fi

echo -e "${CYAN}[INFO]${NC} Found coverage files, generating HTML reports..."

# Initialize coverage data arrays
declare -A file_coverage
declare -A file_lines_covered
declare -A file_lines_total

# Parse all .lst files
for lst_file in $LST_FILES; do
    filename=$(basename "$lst_file" .lst)
    
    # Extract coverage data from .lst file
    # Format: <coverage>|<line_number>|<source_line>
    # coverage is 0000000 for not covered, or a number for times executed
    
    total_lines=0
    covered_lines=0
    
    while IFS='|' read -r coverage line_num source_line; do
        # Skip empty lines
        [ -z "$coverage" ] && continue
        
        total_lines=$((total_lines + 1))
        
        # Check if line was executed (coverage != 0000000)
        if [[ "$coverage" != "0000000" ]] && [[ "$coverage" =~ ^[0-9]+$ ]] && [ "$coverage" -gt 0 ]; then
            covered_lines=$((covered_lines + 1))
        fi
    done < "$lst_file"
    
    if [ $total_lines -gt 0 ]; then
        coverage_percent=$(awk "BEGIN {printf \"%.1f\", ($covered_lines/$total_lines)*100}")
        file_coverage["$filename"]=$coverage_percent
        file_lines_covered["$filename"]=$covered_lines
        file_lines_total["$filename"]=$total_lines
    fi
done

# Generate HTML index
cat > "${COVERAGE_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Builder Test Coverage Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            padding: 30px;
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #007bff;
            padding-bottom: 10px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .metric {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 6px;
            text-align: center;
        }
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #007bff;
        }
        .metric-label {
            color: #666;
            margin-top: 5px;
            font-size: 0.9em;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #007bff;
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .coverage-bar {
            height: 20px;
            background: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            position: relative;
        }
        .coverage-fill {
            height: 100%;
            transition: width 0.3s ease;
        }
        .coverage-high { background: #28a745; }
        .coverage-medium { background: #ffc107; }
        .coverage-low { background: #dc3545; }
        .coverage-text {
            position: absolute;
            width: 100%;
            text-align: center;
            line-height: 20px;
            font-size: 12px;
            font-weight: bold;
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 Builder Test Coverage Report</h1>
        <p>Generated: <strong>DATE_PLACEHOLDER</strong></p>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value" id="total-coverage">0%</div>
                <div class="metric-label">Overall Coverage</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="total-files">0</div>
                <div class="metric-label">Files Analyzed</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="total-lines">0</div>
                <div class="metric-label">Total Lines</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="covered-lines">0</div>
                <div class="metric-label">Covered Lines</div>
            </div>
        </div>
        
        <h2>Coverage by Module</h2>
        <table>
            <thead>
                <tr>
                    <th>Module</th>
                    <th>Coverage</th>
                    <th>Lines</th>
                </tr>
            </thead>
            <tbody id="coverage-table">
                <!-- Data inserted here -->
            </tbody>
        </table>
    </div>
    
    <script>
        const coverageData = COVERAGE_DATA_PLACEHOLDER;
        
        // Calculate totals
        let totalLines = 0;
        let totalCovered = 0;
        
        coverageData.forEach(item => {
            totalLines += item.total;
            totalCovered += item.covered;
        });
        
        const overallCoverage = totalLines > 0 ? (totalCovered / totalLines * 100).toFixed(1) : 0;
        
        // Update summary
        document.getElementById('total-coverage').textContent = overallCoverage + '%';
        document.getElementById('total-files').textContent = coverageData.length;
        document.getElementById('total-lines').textContent = totalLines.toLocaleString();
        document.getElementById('covered-lines').textContent = totalCovered.toLocaleString();
        
        // Populate table
        const tbody = document.getElementById('coverage-table');
        coverageData
            .sort((a, b) => a.coverage - b.coverage)
            .forEach(item => {
                const row = tbody.insertRow();
                
                const cellName = row.insertCell();
                cellName.textContent = item.name;
                
                const cellCoverage = row.insertCell();
                const coverageBar = document.createElement('div');
                coverageBar.className = 'coverage-bar';
                
                const coverageFill = document.createElement('div');
                coverageFill.className = 'coverage-fill';
                if (item.coverage >= 80) coverageFill.className += ' coverage-high';
                else if (item.coverage >= 70) coverageFill.className += ' coverage-medium';
                else coverageFill.className += ' coverage-low';
                coverageFill.style.width = item.coverage + '%';
                
                const coverageText = document.createElement('div');
                coverageText.className = 'coverage-text';
                coverageText.textContent = item.coverage.toFixed(1) + '%';
                
                coverageBar.appendChild(coverageFill);
                coverageBar.appendChild(coverageText);
                cellCoverage.appendChild(coverageBar);
                
                const cellLines = row.insertCell();
                cellLines.textContent = `${item.covered} / ${item.total}`;
            });
    </script>
</body>
</html>
EOF

# Build JSON data for HTML
json_data="["
first=true
for filename in "${!file_coverage[@]}"; do
    coverage="${file_coverage[$filename]}"
    covered="${file_lines_covered[$filename]}"
    total="${file_lines_total[$filename]}"
    
    if [ "$first" = true ]; then
        first=false
    else
        json_data+=","
    fi
    
    json_data+="{\"name\":\"$filename\",\"coverage\":$coverage,\"covered\":$covered,\"total\":$total}"
done
json_data+="]"

# Replace placeholders in HTML
sed -i.bak "s/DATE_PLACEHOLDER/$(date)/" "${COVERAGE_DIR}/index.html"
sed -i.bak "s/COVERAGE_DATA_PLACEHOLDER/$json_data/" "${COVERAGE_DIR}/index.html"
rm -f "${COVERAGE_DIR}/index.html.bak"

echo -e "${GREEN}✓${NC} Coverage report generated: ${COVERAGE_DIR}/index.html"
echo ""
echo "To view: open ${COVERAGE_DIR}/index.html"

exit 0

