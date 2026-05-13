const { execSync } = require('child_process');
try {
  const out = execSync('npm run build', { cwd: './admin-dashboard', stdio: 'pipe' });
  console.log(out.toString());
} catch(e) {
  console.log("ERROR OUTPUT:");
  console.log(e.stdout ? e.stdout.toString() : '');
  console.log(e.stderr ? e.stderr.toString() : '');
}
