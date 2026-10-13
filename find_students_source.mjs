import fs from 'fs';
import path from 'path';

function searchInDir(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules' && entry.name !== '.git' && entry.name !== 'build' && entry.name !== '.dart_tool') {
        searchInDir(fullPath);
      }
    } else {
      if (entry.name.endsWith('.json') || entry.name.endsWith('.js') || entry.name.endsWith('.ts') || entry.name.endsWith('.dart')) {
        try {
          const content = fs.readFileSync(fullPath, 'utf8');
          if (content.includes('Sai Alugolu') || content.includes('Satya Student') || content.includes('Adarsh 3rd')) {
            console.log(`FOUND IN FILE: ${fullPath}`);
          }
        } catch (_) {}
      }
    }
  }
}

searchInDir('.');
