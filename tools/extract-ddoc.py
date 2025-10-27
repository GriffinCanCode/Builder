#!/usr/bin/env python3
"""
Builder DDoc Documentation Extractor
Extracts DDoc comments from D source files and generates HTML documentation
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Tuple
from html import escape

def extract_module_name(content: str) -> str:
    """Extract module name from D source file"""
    match = re.search(r'^\s*module\s+([\w.]+)\s*;', content, re.MULTILINE)
    return match.group(1) if match else "unknown"

def extract_ddoc_comments(content: str) -> List[Dict[str, str]]:
    """Extract DDoc comments (///) from source"""
    docs = []
    lines = content.split('\n')
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for DDoc comment block
        if line.strip().startswith('///'):
            doc_lines = []
            # Collect consecutive /// lines
            while i < len(lines) and lines[i].strip().startswith('///'):
                doc_text = lines[i].strip()[3:].strip()
                doc_lines.append(doc_text)
                i += 1
            
            # Get the next non-empty line (the declaration)
            declaration = ""
            while i < len(lines):
                next_line = lines[i].strip()
                if next_line and not next_line.startswith('//'):
                    # Collect multi-line declarations
                    decl_lines = [next_line]
                    i += 1
                    
                    # Keep collecting if line doesn't end with ; or {
                    while i < len(lines) and not (next_line.endswith(';') or next_line.endswith('{')):
                        next_line = lines[i].strip()
                        if next_line:
                            decl_lines.append(next_line)
                        i += 1
                        if next_line.endswith(';') or next_line.endswith('{'):
                            break
                    
                    declaration = ' '.join(decl_lines)
                    break
                i += 1
            
            docs.append({
                'doc': '\n'.join(doc_lines),
                'declaration': declaration
            })
        else:
            i += 1
    
    return docs

def generate_html(module_name: str, docs: List[Dict[str, str]], source_file: str) -> str:
    """Generate HTML documentation for a module"""
    
    # Split module name into package parts for breadcrumb
    parts = module_name.split('.')
    breadcrumb_html = '<a href="index.html">🏠 Home</a>'
    for i, part in enumerate(parts[:-1]):
        breadcrumb_html += f' <span class="separator">›</span> <span>{escape(part)}</span>'
    if len(parts) > 0:
        breadcrumb_html += f' <span class="separator">›</span> <strong>{escape(parts[-1])}</strong>'
    
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{escape(module_name)} - Builder API Documentation</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {{
            --primary: #667eea;
            --primary-dark: #5568d3;
            --secondary: #764ba2;
            --accent: #f093fb;
            --bg-main: #ffffff;
            --bg-secondary: #f8f9fa;
            --bg-code: #2d3748;
            --text-primary: #1a202c;
            --text-secondary: #4a5568;
            --text-muted: #718096;
            --border: #e2e8f0;
            --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
        }}
        
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        
        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.7;
            color: var(--text-primary);
            background: linear-gradient(to bottom, #f8f9fa 0%, #ffffff 100%);
            min-height: 100vh;
        }}
        
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }}
        
        header {{
            background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
            color: white;
            padding: 40px;
            border-radius: 16px;
            margin-bottom: 40px;
            box-shadow: var(--shadow-lg);
            position: relative;
            overflow: hidden;
        }}
        
        header::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><defs><pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M 10 0 L 0 0 0 10" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="0.5"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
            opacity: 0.3;
        }}
        
        header > * {{ position: relative; z-index: 1; }}
        
        .breadcrumb {{
            font-size: 0.9em;
            margin-bottom: 15px;
            opacity: 0.95;
            font-weight: 400;
        }}
        
        .breadcrumb a {{
            color: white;
            text-decoration: none;
            transition: opacity 0.2s;
        }}
        
        .breadcrumb a:hover {{
            opacity: 0.8;
            text-decoration: underline;
        }}
        
        .separator {{
            margin: 0 8px;
            opacity: 0.6;
        }}
        
        header h1 {{
            font-size: 2.75em;
            font-weight: 700;
            margin-bottom: 12px;
            letter-spacing: -0.02em;
        }}
        
        .source-file {{
            font-family: 'JetBrains Mono', 'Monaco', 'Courier New', monospace;
            font-size: 0.85em;
            opacity: 0.85;
            background: rgba(255, 255, 255, 0.15);
            padding: 6px 12px;
            border-radius: 6px;
            display: inline-block;
            backdrop-filter: blur(10px);
        }}
        
        main {{
            animation: fadeIn 0.6s ease-in;
        }}
        
        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(20px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}
        
        .doc-item {{
            background: var(--bg-main);
            padding: 32px;
            margin-bottom: 24px;
            border-radius: 12px;
            box-shadow: var(--shadow);
            border: 1px solid var(--border);
            transition: all 0.3s ease;
        }}
        
        .doc-item:hover {{
            box-shadow: var(--shadow-lg);
            transform: translateY(-2px);
            border-color: var(--primary);
        }}
        
        .declaration {{
            background: var(--bg-code);
            color: #e2e8f0;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-family: 'JetBrains Mono', 'Monaco', monospace;
            overflow-x: auto;
            font-size: 0.9em;
            line-height: 1.6;
            border-left: 4px solid var(--primary);
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
        }}
        
        .declaration::-webkit-scrollbar {{
            height: 8px;
        }}
        
        .declaration::-webkit-scrollbar-track {{
            background: rgba(0,0,0,0.1);
            border-radius: 4px;
        }}
        
        .declaration::-webkit-scrollbar-thumb {{
            background: rgba(255,255,255,0.3);
            border-radius: 4px;
        }}
        
        .declaration::-webkit-scrollbar-thumb:hover {{
            background: rgba(255,255,255,0.4);
        }}
        
        .description {{
            color: var(--text-secondary);
            white-space: pre-wrap;
            line-height: 1.8;
            font-size: 1.05em;
        }}
        
        .description h3 {{
            color: var(--text-primary);
            margin-top: 20px;
            margin-bottom: 12px;
            font-weight: 600;
            font-size: 1.2em;
        }}
        
        code {{
            background: var(--bg-secondary);
            color: var(--primary-dark);
            padding: 3px 8px;
            border-radius: 4px;
            font-family: 'JetBrains Mono', 'Monaco', monospace;
            font-size: 0.9em;
            border: 1px solid var(--border);
        }}
        
        .keyword {{
            color: #c678dd;
            font-weight: 600;
        }}
        
        .type {{
            color: #56b6c2;
        }}
        
        .string {{
            color: #98c379;
        }}
        
        .comment {{
            color: #5c6370;
            font-style: italic;
        }}
        
        footer {{
            text-align: center;
            margin-top: 60px;
            padding: 30px;
            color: var(--text-muted);
            font-size: 0.9em;
            border-top: 1px solid var(--border);
        }}
        
        .no-docs {{
            background: linear-gradient(135deg, #fff9e6 0%, #fff3cd 100%);
            border: 2px solid #ffc107;
            padding: 30px;
            border-radius: 12px;
            color: #856404;
            text-align: center;
        }}
        
        .no-docs h3 {{
            font-size: 1.5em;
            margin-bottom: 10px;
        }}
        
        /* Back to top button */
        .back-to-top {{
            position: fixed;
            bottom: 30px;
            right: 30px;
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            color: white;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            text-decoration: none;
            box-shadow: var(--shadow-lg);
            opacity: 0;
            pointer-events: none;
            transition: all 0.3s ease;
            font-size: 1.5em;
        }}
        
        .back-to-top.visible {{
            opacity: 1;
            pointer-events: all;
        }}
        
        .back-to-top:hover {{
            transform: translateY(-3px);
            box-shadow: 0 15px 30px -5px rgba(0, 0, 0, 0.2);
        }}
        
        /* Mobile responsiveness */
        @media (max-width: 768px) {{
            header {{
                padding: 30px 20px;
            }}
            
            header h1 {{
                font-size: 2em;
            }}
            
            .doc-item {{
                padding: 20px;
            }}
            
            .container {{
                padding: 15px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="breadcrumb">
                {breadcrumb_html}
            </div>
            <h1>{escape(module_name)}</h1>
            <div class="source-file">📄 {escape(source_file)}</div>
        </header>
        
        <main>
"""
    
    if not docs:
        html += """
            <div class="no-docs">
                <h3>⚠️ No documentation found</h3>
                <p>This module doesn't have DDoc comments yet.</p>
            </div>
        """
    else:
        for doc_item in docs:
            declaration = doc_item['declaration']
            description = doc_item['doc']
            
            # Syntax highlight keywords
            keywords = ['module', 'import', 'class', 'struct', 'interface', 'enum', 
                       'public', 'private', 'protected', 'static', 'const', 'immutable',
                       'pure', 'nothrow', '@safe', '@trusted', '@system', '@nogc',
                       'void', 'int', 'string', 'bool', 'auto', 'return', 'if', 'else']
            
            highlighted = escape(declaration)
            for kw in keywords:
                highlighted = re.sub(r'\b' + kw + r'\b', 
                                   f'<span class="keyword">{kw}</span>', 
                                   highlighted)
            
            html += f"""
            <div class="doc-item">
                <div class="declaration">{highlighted}</div>
                <div class="description">{escape(description)}</div>
            </div>
"""
    
    html += """
        </main>
        
        <footer>
            <p><strong>Builder</strong> - High-Performance Build System</p>
            <p>Generated by hand by Griffin using the Builder DDoc Extractor | &copy; 2025 Griffin</p>
        </footer>
    </div>
    
    <a href="#" class="back-to-top" id="backToTop">↑</a>
    
    <script>
        // Back to top button
        const backToTop = document.getElementById('backToTop');
        
        window.addEventListener('scroll', () => {{
            if (window.pageYOffset > 300) {{
                backToTop.classList.add('visible');
            }} else {{
                backToTop.classList.remove('visible');
            }}
        }});
        
        backToTop.addEventListener('click', (e) => {{
            e.preventDefault();
            window.scrollTo({{ top: 0, behavior: 'smooth' }});
        }});
    </script>
</body>
</html>
"""
    
    return html

def process_source_file(source_path: Path, source_dir: Path, output_dir: Path):
    """Process a single D source file"""
    try:
        with open(source_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        module_name = extract_module_name(content)
        docs = extract_ddoc_comments(content)
        
        # Generate output path
        rel_path = source_path.relative_to(source_dir)
        module_path = str(rel_path).replace('/', '.').replace('.d', '')
        output_file = output_dir / f"{module_path}.html"
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Generate HTML
        html = generate_html(module_name, docs, str(rel_path))
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html)
        
        return module_name, len(docs) > 0
        
    except Exception as e:
        print(f"Error processing {source_path}: {e}", file=sys.stderr)
        return None, False

def generate_index(modules: List[Tuple[str, str]], output_dir: Path):
    """Generate index.html"""
    # Group modules by package
    packages = {}
    for module_name, module_file in modules:
        package = module_name.split('.')[0]
        if package not in packages:
            packages[package] = []
        packages[package].append((module_name, module_file))
    
    html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Builder API Documentation</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;900&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #667eea;
            --secondary: #764ba2;
            --accent: #f093fb;
            --success: #48bb78;
            --warning: #ed8936;
            --bg-main: #ffffff;
            --text-primary: #1a202c;
            --text-secondary: #4a5568;
            --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: var(--text-primary);
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        header {
            text-align: center;
            color: white;
            margin-bottom: 50px;
            animation: fadeInDown 0.8s ease-out;
        }
        
        @keyframes fadeInDown {
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        header .logo {
            font-size: 5em;
            margin-bottom: 10px;
            filter: drop-shadow(0 4px 8px rgba(0,0,0,0.2));
        }
        
        header h1 {
            font-size: 4em;
            font-weight: 900;
            margin-bottom: 15px;
            text-shadow: 2px 4px 8px rgba(0,0,0,0.3);
            letter-spacing: -0.02em;
        }
        
        header p {
            font-size: 1.4em;
            opacity: 0.95;
            font-weight: 300;
            text-shadow: 1px 2px 4px rgba(0,0,0,0.2);
        }
        
        .search-bar {
            max-width: 600px;
            margin: 30px auto 0;
            position: relative;
        }
        
        .search-bar input {
            width: 100%;
            padding: 15px 50px 15px 20px;
            border: none;
            border-radius: 50px;
            font-size: 1.1em;
            font-family: inherit;
            box-shadow: var(--shadow-xl);
            transition: all 0.3s ease;
        }
        
        .search-bar input:focus {
            outline: none;
            transform: translateY(-2px);
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
        }
        
        .search-bar::after {
            content: '🔍';
            position: absolute;
            right: 20px;
            top: 50%;
            transform: translateY(-50%);
            font-size: 1.3em;
            pointer-events: none;
        }
        
        .content {
            background: white;
            border-radius: 20px;
            padding: 50px;
            box-shadow: var(--shadow-xl);
            animation: fadeInUp 0.8s ease-out 0.2s both;
        }
        
        .intro {
            margin-bottom: 50px;
            padding-bottom: 40px;
            border-bottom: 3px solid #f0f4f8;
        }
        
        .intro h2 {
            color: var(--primary);
            margin-bottom: 20px;
            font-size: 2.5em;
            font-weight: 700;
        }
        
        .intro p {
            font-size: 1.15em;
            color: var(--text-secondary);
            line-height: 1.8;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 30px;
            margin: 40px 0;
        }
        
        .stat {
            text-align: center;
            padding: 30px;
            background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);
            border-radius: 16px;
            box-shadow: var(--shadow);
            transition: all 0.3s ease;
            border: 2px solid transparent;
        }
        
        .stat:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: var(--primary);
        }
        
        .stat-number {
            font-size: 3.5em;
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            font-weight: 900;
            line-height: 1.2;
        }
        
        .stat-label {
            color: var(--text-secondary);
            font-size: 0.95em;
            text-transform: uppercase;
            letter-spacing: 1.5px;
            font-weight: 600;
            margin-top: 10px;
        }
        
        .modules h2 {
            color: var(--primary);
            margin-bottom: 30px;
            font-size: 2.2em;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .module-group {
            margin-bottom: 40px;
            animation: fadeInUp 0.6s ease-out both;
        }
        
        .module-group:nth-child(1) { animation-delay: 0.1s; }
        .module-group:nth-child(2) { animation-delay: 0.2s; }
        .module-group:nth-child(3) { animation-delay: 0.3s; }
        .module-group:nth-child(4) { animation-delay: 0.4s; }
        .module-group:nth-child(5) { animation-delay: 0.5s; }
        
        .module-group h3 {
            color: var(--text-primary);
            margin-bottom: 20px;
            padding: 15px 20px;
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            color: white;
            border-radius: 12px;
            font-size: 1.5em;
            font-weight: 600;
            box-shadow: var(--shadow);
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .module-group h3::before {
            content: '📦';
            font-size: 1.2em;
        }
        
        .module-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 15px;
            list-style: none;
        }
        
        .module-list li {
            background: white;
            border: 2px solid #e2e8f0;
            padding: 18px 20px;
            border-radius: 10px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .module-list li::before {
            content: '';
            position: absolute;
            left: 0;
            top: 0;
            bottom: 0;
            width: 4px;
            background: linear-gradient(180deg, var(--primary), var(--secondary));
            transform: scaleY(0);
            transition: transform 0.3s ease;
        }
        
        .module-list li:hover {
            border-color: var(--primary);
            transform: translateX(5px);
            box-shadow: var(--shadow-lg);
        }
        
        .module-list li:hover::before {
            transform: scaleY(1);
        }
        
        .module-list a {
            color: var(--text-primary);
            text-decoration: none;
            font-weight: 500;
            display: block;
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.95em;
        }
        
        .module-list a:hover {
            color: var(--primary);
        }
        
        .footer {
            text-align: center;
            margin-top: 60px;
            color: white;
            opacity: 0.9;
            font-size: 1em;
        }
        
        .footer p {
            margin: 8px 0;
        }
        
        /* Mobile responsiveness */
        @media (max-width: 768px) {
            header h1 {
                font-size: 2.5em;
            }
            
            header .logo {
                font-size: 3em;
            }
            
            .content {
                padding: 30px 20px;
            }
            
            .intro h2 {
                font-size: 2em;
            }
            
            .module-list {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">🔨</div>
            <h1>Builder</h1>
            <p>API Documentation</p>
            <div class="search-bar">
                <input type="text" id="searchInput" placeholder="Search modules..." />
            </div>
        </header>
        
        <div class="content">
            <div class="intro">
                <h2>Welcome to Builder Documentation</h2>
                <p>
                    Builder is a <strong>high-performance build system</strong> for mixed-language monorepos with 
                    compile-time dependency analysis. This documentation covers the complete API 
                    with detailed module descriptions, function signatures, and usage examples.
                </p>
            </div>
            
            <div class="stats">
                <div class="stat">
                    <div class="stat-number">""" + str(len(modules)) + """</div>
                    <div class="stat-label">Modules</div>
                </div>
                <div class="stat">
                    <div class="stat-number">20+</div>
                    <div class="stat-label">Languages</div>
                </div>
                <div class="stat">
                    <div class="stat-number">100%</div>
                    <div class="stat-label">Type Safe</div>
                </div>
            </div>
            
            <div class="modules">
                <h2>📚 Module Index</h2>
"""
    
    for package in sorted(packages.keys()):
        html += f"""
                <div class="module-group">
                    <h3>{package}</h3>
                    <ul class="module-list">
"""
        for module_name, module_file in sorted(packages[package]):
            html += f'                        <li><a href="{module_file}">{escape(module_name)}</a></li>\n'
        
        html += """                    </ul>
                </div>
"""
    
    html += """
            </div>
        </div>
        
        <div class="footer">
            <p><strong>Builder</strong> - High-Performance Build System</p>
            <p>Generated by hand by Griffin using the Builder DDoc Extractor | &copy; 2025 Griffin</p>
        </div>
    </div>
    
    <script>
        // Search functionality
        const searchInput = document.getElementById('searchInput');
        const moduleGroups = document.querySelectorAll('.module-group');
        
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();
            
            moduleGroups.forEach(group => {
                const moduleList = group.querySelector('.module-list');
                const items = moduleList.querySelectorAll('li');
                let visibleCount = 0;
                
                items.forEach(item => {
                    const text = item.textContent.toLowerCase();
                    if (text.includes(searchTerm)) {
                        item.style.display = '';
                        visibleCount++;
                    } else {
                        item.style.display = 'none';
                    }
                });
                
                // Hide group if no visible items
                group.style.display = visibleCount > 0 ? '' : 'none';
            });
        });
        
        // Smooth scroll for any future anchors
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth' });
                }
            });
        });
    </script>
</body>
</html>
"""
    
    with open(output_dir / "index.html", 'w', encoding='utf-8') as f:
        f.write(html)

def main():
    if len(sys.argv) < 3:
        print("Usage: extract-ddoc.py <source_dir> <output_dir>")
        sys.exit(1)
    
    source_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all D source files
    d_files = list(source_dir.rglob("*.d"))
    print(f"Found {len(d_files)} D source files")
    
    modules = []
    documented = 0
    
    for i, source_file in enumerate(d_files, 1):
        print(f"\rProcessing [{i}/{len(d_files)}]: {source_file.name}", end='', flush=True)
        module_name, has_docs = process_source_file(source_file, source_dir, output_dir)
        
        if module_name:
            rel_path = source_file.relative_to(source_dir)
            module_file = str(rel_path).replace('/', '.').replace('.d', '') + '.html'
            modules.append((module_name, module_file))
            if has_docs:
                documented += 1
    
    print()  # New line after progress
    
    # Generate index
    print("Generating index page...")
    generate_index(modules, output_dir)
    
    print(f"\n✨ Done! Generated documentation for {len(modules)} modules")
    print(f"📊 {documented} modules have documentation")
    print(f"📁 Output: {output_dir}")

if __name__ == "__main__":
    main()

