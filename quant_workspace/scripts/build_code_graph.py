import os
import ast
import json
import re

def parse_python_file(filepath):
    """Parses Python file imports and classes/functions using AST"""
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
        
    imports = []
    classes = {}
    functions = []
    
    try:
        tree = ast.parse(content)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for name in node.names:
                    imports.append(name.name)
            elif isinstance(node, ast.ImportFrom):
                imports.append(f"{node.module}.{node.names[0].name}" if node.module else node.names[0].name)
            elif isinstance(node, ast.ClassDef):
                methods = [n.name for n in node.body if isinstance(n, ast.FunctionDef)]
                classes[node.name] = {
                    "methods": methods,
                    "line": node.lineno
                }
            elif isinstance(node, ast.FunctionDef):
                functions.append(node.name)
    except:
        pass
        
    return {
        "type": "python",
        "imports": imports,
        "classes": classes,
        "functions": functions
    }

def parse_mql_file(filepath):
    """Parses MQL5 file includes and class declarations using regex"""
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
        
    includes = re.findall(r'#include\s+["<](.*?)[">]', content)
    classes = {}
    
    # Simple regex for class matching
    class_matches = re.finditer(r'class\s+(\w+)', content)
    for m in class_matches:
        class_name = m.group(1)
        classes[class_name] = {
            "methods": [],
            "line": content.count("\n", 0, m.start()) + 1
        }
        
    return {
        "type": "mql5",
        "includes": includes,
        "classes": classes
    }

def build_graph():
    workspace_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parent_root = os.path.dirname(workspace_root)
    
    graph = {}
    
    scan_paths = {
        "quant_workspace": workspace_root,
        "bot_trend_ai": os.path.join(parent_root, "Bot Trend AI")
    }
    
    for label, path in scan_paths.items():
        if not os.path.exists(path):
            continue
            
        for root, dirs, files in os.walk(path):
            # Ignore patterns
            if any(x in root for x in [".venv", "node_modules", "dist", "build", "logs", "reports", "cache"]):
                continue
                
            for file in files:
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, parent_root)
                
                if file.endswith(".py"):
                    graph[rel_path] = parse_python_file(filepath)
                elif file.endswith((".mq5", ".mqh")):
                    graph[rel_path] = parse_mql_file(filepath)
                    
    # Write report
    report_dir = os.path.join(workspace_root, "reports")
    os.makedirs(report_dir, exist_ok=True)
    report_path = os.path.join(report_dir, "code_graph_index.json")
    
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(graph, f, indent=2)
        
    print(f"Code graph successfully built with {len(graph)} nodes!")
    print(f"Index output -> {report_path}")

if __name__ == "__main__":
    build_graph()
