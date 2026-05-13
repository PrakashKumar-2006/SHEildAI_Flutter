const fs = require('fs');
const path = require('path');

const dir = 'c:/Users/maury/SHEildAI_Flutter/admin-dashboard/src';

function walk(directory) {
  const files = fs.readdirSync(directory);
  for (const file of files) {
    const fullPath = path.join(directory, file);
    if (fs.statSync(fullPath).isDirectory()) {
      walk(fullPath);
    } else if (fullPath.endsWith('.jsx')) {
      let content = fs.readFileSync(fullPath, 'utf8');
      let changed = false;

      if (content.includes('LuAlertTriangle')) {
        content = content.replace(/LuAlertTriangle/g, 'LuTriangleAlert');
        changed = true;
      }
      if (content.includes('LuAlertOctagon')) {
        content = content.replace(/LuAlertOctagon/g, 'LuOctagonAlert');
        changed = true;
      }
      if (content.includes('LuCheckCircle')) {
        content = content.replace(/LuCheckCircle/g, 'LuCheck');
        changed = true;
      }
      
      if (changed) {
        fs.writeFileSync(fullPath, content);
        console.log('Fixed', fullPath);
      }
    }
  }
}

walk(dir);
