import os
import sys
import hashlib
import sqlite3

def get_files_recursively(dir_path):
    file_list = []
    for root, dirs, files in os.walk(dir_path):
        # In-place modify dirs to exclude directories starting with a dot, tools, or .git/.github
        dirs[:] = [d for d in dirs if d not in ('.git', '.github', 'tools') and not d.startswith('.')]
        for file in files:
            if file.endswith(('.md', '.nix', '.json', '.txt')):
                file_list.append(os.path.join(root, file))
    return file_list

def parse_yaml_frontmatter(content):
    meta = {'title': '', 'status': 'active', 'tags': []}
    clean_content = content
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            yaml_content = parts[1]
            clean_content = parts[2].strip()
            for line in yaml_content.splitlines():
                if ':' in line:
                    key, val = line.split(':', 1)
                    key = key.strip().lower()
                    val = val.strip()
                    # Strip quotes
                    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    # Parse lists like [a, b, c]
                    if val.startswith('[') and val.endswith(']'):
                        val = [v.strip().replace('"', '').replace("'", "") for v in val[1:-1].split(',')]
                    
                    if key == 'title':
                        meta['title'] = val
                    elif key == 'status':
                        meta['status'] = val
                    elif key == 'tags':
                        meta['tags'] = val if isinstance(val, list) else [val]
    return meta, clean_content

def build_docs_db(target_dir, files):
    db_path = os.path.join(target_dir, 'nixos_docs.db')
    print(f"Building relational database at: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("PRAGMA foreign_keys = ON;")
    cursor.execute("DROP TABLE IF EXISTS document_tags;")
    cursor.execute("DROP TABLE IF EXISTS documents;")
    
    cursor.execute("""
        CREATE TABLE documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          path TEXT UNIQUE NOT NULL,
          title TEXT NOT NULL,
          status TEXT,
          content TEXT NOT NULL
        );
    """)
    
    cursor.execute("""
        CREATE TABLE document_tags (
          document_id INTEGER,
          tag TEXT NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
          PRIMARY KEY (document_id, tag)
        );
    """)
    
    for file in files:
        if os.path.basename(file) in ('nixos_docs.db', 'memdb.db'):
            continue
            
        relative_path = os.path.relpath(file, target_dir).replace('\\', '/')
        
        with open(file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        meta = {'title': relative_path, 'status': 'active', 'tags': []}
        clean_content = content
        
        if file.endswith('.md'):
            meta, clean_content = parse_yaml_frontmatter(content)
            if not meta['title']:
                meta['title'] = relative_path
        elif file.endswith('.nix'):
            meta['title'] = f"Nix-Konfiguration: {os.path.basename(file)}"
            meta['tags'] = ['nix', 'nixos', 'configuration']
        elif file.endswith('.json'):
            meta['title'] = f"JSON: {os.path.basename(file)}"
            meta['tags'] = ['json']
        elif file.endswith('.txt'):
            meta['title'] = f"Text: {os.path.basename(file)}"
            meta['tags'] = ['text']
            
        if relative_path.startswith('_Templates/'):
            meta['status'] = 'template'
            if 'template' not in meta['tags']:
                meta['tags'].append('template')
            if file.endswith('.nix'):
                meta['title'] = f"Nix-Template: {os.path.basename(file)}"
            elif file.endswith('.md'):
                meta['title'] = f"Markdown-Template: {os.path.basename(file)}"
                
        title = meta['title'] or os.path.basename(file)
        status = meta['status'] or 'active'
        
        cursor.execute(
            "INSERT INTO documents (path, title, status, content) VALUES (?, ?, ?, ?);",
            (relative_path, title, status, clean_content)
        )
        
        # Get last inserted id
        doc_id = cursor.lastrowid
        
        for tag in meta['tags']:
            if tag:
                cursor.execute(
                    "INSERT OR IGNORE INTO document_tags (document_id, tag) VALUES (?, ?);",
                    (doc_id, tag)
                )
                
    conn.commit()
    conn.close()
    print("Relational database built successfully!")

def build_memdb(target_dir, files):
    db_path = os.path.join(target_dir, 'memdb.db')
    print(f"Building semantic memory database at: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Initialize schema
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS memories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          summary TEXT,
          importance INTEGER DEFAULT 0,
          memory_type TEXT DEFAULT 'general',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          accessed_at TEXT DEFAULT CURRENT_TIMESTAMP,
          hash TEXT NOT NULL UNIQUE
        );
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS relationships (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_memory_id INTEGER NOT NULL,
          to_memory_id INTEGER NOT NULL,
          relation_type TEXT NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS tags (
          memory_id INTEGER NOT NULL,
          tag TEXT NOT NULL,
          PRIMARY KEY (memory_id, tag)
        );
    """)
    
    # Try to create FTS virtual table (ignore if already exists)
    try:
        cursor.execute("CREATE VIRTUAL TABLE memories_fts USING fts5(content, summary, tokenize = 'porter');")
    except sqlite3.OperationalError:
        pass
        
    # Clean up old document memories and their FTS/tag relationships
    cursor.execute("DELETE FROM memories_fts WHERE rowid IN (SELECT id FROM memories WHERE memory_type = 'general');")
    cursor.execute("DELETE FROM memories WHERE memory_type = 'general';")
    cursor.execute("DELETE FROM tags WHERE memory_id NOT IN (SELECT id FROM memories);")
    cursor.execute("DELETE FROM relationships WHERE from_memory_id NOT IN (SELECT id FROM memories) OR to_memory_id NOT IN (SELECT id FROM memories);")
    
    for file in files:
        if os.path.basename(file) in ('nixos_docs.db', 'memdb.db'):
            continue
            
        relative_path = os.path.relpath(file, target_dir).replace('\\', '/')
        
        with open(file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        meta = {'title': relative_path, 'status': 'active', 'tags': []}
        
        if file.endswith('.md'):
            meta, _ = parse_yaml_frontmatter(content)
            if not meta['title']:
                meta['title'] = relative_path
            meta['tags'].append('markdown')
        elif file.endswith('.nix'):
            meta['title'] = f"Nix-Konfiguration: {os.path.basename(file)}"
            meta['tags'] = ['nix', 'nixos', 'configuration']
        elif file.endswith('.json'):
            meta['title'] = f"JSON: {os.path.basename(file)}"
            meta['tags'] = ['json']
        elif file.endswith('.txt'):
            meta['title'] = f"Text: {os.path.basename(file)}"
            meta['tags'] = ['text']
            
        title = meta['title'] or os.path.basename(file)
        summary = f"{title} ({relative_path})"
        
        content_hash = hashlib.sha256(content.encode('utf-8')).hexdigest()
        
        try:
            cursor.execute(
                "INSERT OR REPLACE INTO memories (content, summary, importance, memory_type, hash) VALUES (?, ?, ?, ?, ?);",
                (content, summary, 5, 'general', content_hash)
            )
            memory_id = cursor.lastrowid
            
            for tag in meta['tags']:
                if tag:
                    cursor.execute(
                        "INSERT OR IGNORE INTO tags (memory_id, tag) VALUES (?, ?);",
                        (memory_id, tag)
                    )
            
            cursor.execute(
                "INSERT OR REPLACE INTO memories_fts (rowid, content, summary) VALUES (?, ?, ?);",
                (memory_id, content, summary)
            )
        except Exception as e:
            print(f"Error importing memory {relative_path}: {e}")
            
    conn.commit()
    conn.close()
    print("Semantic memory database built successfully!")

def main():
    target_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    print(f"Scanning directory: {target_dir}")
    files = get_files_recursively(target_dir)
    print(f"Found {len(files)} files to compile.")
    
    build_docs_db(target_dir, files)
    build_memdb(target_dir, files)
    print("All databases successfully compiled & updated!")

if __name__ == '__main__':
    main()
