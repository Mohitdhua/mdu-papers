const fs = require('fs');
const path = require('path');

const llbPath = path.resolve(__dirname, '../frontend/dist/llb/index.html');
if (fs.existsSync(llbPath)) {
  const content = fs.readFileSync(llbPath, 'utf8');
  console.log('--- LLB index.html ---');
  // Find all links to semesters
  const matches = content.match(/href="\/llb\/[^"]*"/g) || [];
  console.log('LLB semester links in index.html:', matches);
}

const mbaPath = path.resolve(__dirname, '../frontend/dist/mba/index.html');
if (fs.existsSync(mbaPath)) {
  const content = fs.readFileSync(mbaPath, 'utf8');
  console.log('--- MBA index.html ---');
  const matches = content.match(/href="\/mba\/[^"]*"/g) || [];
  console.log('MBA semester links in index.html:', matches);
}
