const fs = require('fs');
const content = fs.readFileSync('c:/Users/maury/SHEildAI_Flutter/admin-dashboard/node_modules/react-icons/lu/index.d.ts', 'utf8');
const exports = content.split('\n').filter(l => l.includes('export declare const')).map(l => l.split(' ')[3].replace(':', ''));

const missing = [
  'LuCheckCircle', 'LuShieldAlert', 'LuUsers', 'LuAlertTriangle', 'LuAlertOctagon', 'LuContact', 'LuTrendingUp', 'LuMap',
  'LuSearch', 'LuTrash2', 'LuStar', 'LuActivity', 'LuTrendingDown', 'LuEdit2', 'LuCheck', 'LuLayoutDashboard', 'LuShieldCheck'
].filter(icon => !exports.includes(icon));

console.log("Missing icons:", missing);
