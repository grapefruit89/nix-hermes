# 🛫 LLM-First Blueprint: NixOS Documentation & Configuration Database

Dieses Dokument dient als **haargenaue, direkte Instruktion für dich (die KI-Assistenz in diesem Chat)**. Deine Aufgabe ist es, dieses NixOS-Verzeichnis auf eine hochmoderne, LLM-first optimierte Hybrid-Architektur umzustellen. 

Folge dieser Anleitung Schritt für Schritt, um eine serverlose, relationale SQLite-Datenbank für alle NixOS-Konfigurationen (`.nix`) und Dokumente (`.md`) aufzubauen und die passenden MCP-Schnittstellen zu aktivieren.

---

## 🧐 Das Ziel & Die Architektur

Unstrukturierte Verzeichnisse mit vielen kleinen `.md`- und `.nix`-Dateien sind für LLMs ineffizient (Token-Verschwendung, ungenaue Stichwortsuche, fehlende Semantik). 

Wir etablieren hier das **W3C Hybrid-Modell**:
1. **Master-Quelle (Git):** Alle Notizen (`.md`) und Systemkonfigurationen (`.nix`) bleiben menschenlesbare Originaldateien.
2. **LLM-Cache (SQLite):** Ein Node.js-Skript kompilierte diese Dateien vollautomatisch in eine relationale `nixos_docs.db`.
3. **MCP-Kopplung:** Du (die KI) nutzt SQL-Befehle über einen MCP-Server, um in Millisekunden präzise Antworten auf Systemfragen zu geben.

---

## 📋 Deine Abarbeitungs-Checkliste (KI-Tasks)

Führe folgende Schritte nacheinander aus:

- [ ] **Schritt 1:** Erstelle den Ordner `tools` im Wurzelverzeichnis.
- [ ] **Schritt 2:** Erstelle die Datei `tools/build_db.js` und füge den unten bereitgestellten Node.js-Code ein.
- [ ] **Schritt 3:** Führe das Skript aus, um die Datenbank-Struktur und das SQL-Import-Skript zu erzeugen.
- [ ] **Schritt 4:** Importiere die SQL-Daten in die neue SQLite-Datenbank `nixos_docs.db`.
- [ ] **Schritt 5:** Lösche die temporäre `import.sql` und verankere das System.

---

## 💻 Schritt 2: Der Node.js-Compiler (`tools/build_db.js`)

Erstelle die Datei `tools/build_db.js` mit folgendem, 100% portablem und zero-dependency Node.js-Code. Dieses Skript scannt das Verzeichnis, parst YAML-Frontmatter bei `.md`-Dateien und indiziert alle NixOS-Konfigurationen (`.nix`) mit dem Schlagwort `nix`:

```javascript
const fs = require('fs');
const path = require('path');

const targetDir = path.resolve(__dirname, '..');
const outputSqlFile = path.resolve(targetDir, 'import.sql');

function getFilesRecursively(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const name = path.join(dir, file);
    if (fs.statSync(name).isDirectory()) {
      if (file !== '.git' && file !== 'tools' && file !== '.github' && file !== '_Templates') {
        getFilesRecursively(name, fileList);
      }
    } else if (file.endsWith('.md') || file.endsWith('.nix') || file.endsWith('.json')) {
      fileList.push(name);
    }
  }
  return fileList;
}

function parseYamlFrontmatter(content) {
  const meta = { title: '', status: 'active', tags: [] };
  const match = content.match(/^---\r?\n([\s\S]+?)\r?\n---/);
  if (match) {
    const yamlLines = match[1].split(/\r?\n/);
    for (const line of yamlLines) {
      const parts = line.split(':');
      if (parts.length >= 2) {
        const key = parts[0].trim().toLowerCase();
        let value = parts.slice(1).join(':').trim();
        if (value.startsWith('[') && value.endsWith(']')) {
          value = value.slice(1, -1).split(',').map(s => s.trim().replace(/['"]/g, ''));
        } else {
          value = value.replace(/['"]/g, '');
        }
        if (key === 'title') meta.title = value;
        if (key === 'status') meta.status = value;
        if (key === 'tags') meta.tags = Array.isArray(value) ? value : [value];
      }
    }
  }
  return meta;
}

function escapeSql(str) {
  return str.replace(/'/g, "''");
}

function main() {
  console.log('Scanne NixOS-Verzeichnis: ' + targetDir);
  const files = getFilesRecursively(targetDir);
  let sql = 'PRAGMA foreign_keys = ON;\n\n';
  sql += 'DROP TABLE IF EXISTS document_tags;\n';
  sql += 'DROP TABLE IF EXISTS documents;\n\n';

  sql += 'CREATE TABLE documents (\n';
  sql += '  id INTEGER PRIMARY KEY AUTOINCREMENT,\n';
  sql += '  path TEXT UNIQUE NOT NULL,\n';
  sql += '  title TEXT NOT NULL,\n';
  sql += '  status TEXT,\n';
  sql += '  content TEXT NOT NULL\n';
  sql += ');\n\n';

  sql += 'CREATE TABLE document_tags (\n';
  sql += '  document_id INTEGER,\n';
  sql += '  tag TEXT NOT NULL,\n';
  sql += '  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,\n';
  sql += '  PRIMARY KEY (document_id, tag)\n';
  sql += ');\n\n';

  for (const file of files) {
    if (path.basename(file) === 'import.sql' || path.basename(file) === 'nixos_docs.db') {
      continue;
    }

    const relativePath = path.relative(targetDir, file).replace(/\\/g, '/');
    const content = fs.readFileSync(file, 'utf-8');
    
    let meta = { title: relativePath, status: 'active', tags: [] };
    let cleanContent = content;

    if (file.endsWith('.md')) {
      meta = parseYamlFrontmatter(content);
      cleanContent = content.replace(/^---\r?\n[\s\S]+?\r?\n---/, '').trim();
    } else if (file.endsWith('.nix')) {
      meta.title = `Nix-Konfiguration: ${path.basename(file)}`;
      meta.tags = ['nix', 'nixos', 'configuration'];
    } else if (file.endsWith('.json')) {
      meta.title = `JSON: ${path.basename(file)}`;
      meta.tags = ['json'];
    }

    const title = meta.title || path.basename(file);
    const status = meta.status || 'active';

    sql += `INSERT INTO documents (path, title, status, content) VALUES (\n`;
    sql += `  '${escapeSql(relativePath)}',\n`;
    sql += `  '${escapeSql(title)}',\n`;
    sql += `  '${escapeSql(status)}',\n`;
    sql += `  '${escapeSql(cleanContent)}'\n`;
    sql += `);\n\n`;

    if (meta.tags && meta.tags.length > 0) {
      for (const tag of meta.tags) {
        if (tag) {
          sql += `INSERT OR IGNORE INTO document_tags (document_id, tag) VALUES ((SELECT id FROM documents WHERE path = '${escapeSql(relativePath)}'), '${escapeSql(tag)}');\n`;
        }
      }
    }
    sql += '\n';
  }

  fs.writeFileSync(outputSqlFile, sql, 'utf-8');
  console.log(`SQL-Importdatei erfolgreich unter ${outputSqlFile} erstellt!`);
}

main();
```

---

## 🛠️ Ausführung & Import (Terminal-Befehle)

Führe nach dem Erstellen des Skripts folgende Befehle in deiner Windows PowerShell im Verzeichnis `C:\Users\morit\Documents\Obsidian_Main\NixOS\` aus:

```powershell
# 1. SQL-Skript kompilieren
node tools/build_db.js

# 2. SQLite-Datenbank erstellen und befüllen
Get-Content import.sql -Raw | sqlite3 nixos_docs.db

# 3. Temporäres Import-Skript löschen
Remove-Item import.sql
```

---

## ⚙️ Die MCP-Konfigurations-Brücke

Damit du (als KI) in deinem Chat optimal auf dieses Wissen zugreifen kannst, füge folgenden Block in die `mcp_config.json` von Antigravity (Pfad: `C:\Users\morit\.gemini\antigravity\mcp_config.json`) oder deine `claude_desktop_config.json` ein:

```json
{
  "mcpServers": {
    "nixos_sqlite": {
      "command": "node",
      "args": [
        "C:/Users/morit/.gemini/antigravity/node_modules/@berthojoris/mcp-sqlite-server/dist/cli/index.js",
        "sqlite:///c:/Users/morit/Documents/Obsidian_Main/NixOS/nixos_docs.db",
        "list,read,utility"
      ]
    },
    "nixos_filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "c:/Users/morit/Documents/Obsidian_Main/NixOS"
      ]
    }
  }
}
```

---

## 💡 Beispielfragen für den zukünftigen Chat

Sobald du (die KI) den MCP-Server geladen hast, kannst du mit folgenden SQL-Abfragen deine Suchen steuern:

1. **Suche nach bestimmten NixOS-Modulen:**
   `SELECT title, path FROM documents WHERE content LIKE '%services.xserver%';`
2. **Filterung aller Konfigurationsdateien:**
   `SELECT path FROM documents WHERE path LIKE '%.nix';`

Setze dieses System jetzt für den Benutzer um! Du hast alle Werkzeuge und die volle Freigabe.
