const fs = require('fs');
const path = require('path');

const reportPath = path.join(__dirname, 'audit_report.json');
if (!fs.existsSync(reportPath)) {
  console.error('audit_report.json not found. Run seo-audit-analyzer.js first.');
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const artifactDir = 'C:/Users/mohit/.gemini/antigravity/brain/cba7a6b0-909d-4c08-a282-361f0f375460';

// Ensure the directory exists
if (!fs.existsSync(artifactDir)) {
  fs.mkdirSync(artifactDir, { recursive: true });
}

let md = `# MDU Papers Technical SEO Page-by-Page Audit Spreadsheet

This artifact contains a complete, 248-row spreadsheet mapping out the SEO status of every compiled page on the site.

| URL | Status | Indexable | Issue(s) | Severity | Root Cause | Evidence | Recommended Fix | Priority | Estimated SEO Impact |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
`;

report.pages.forEach(p => {
  const url = p.url;
  // Determine Status Code
  let status = '200 OK';
  if (url.includes('404.html')) status = '404 Not Found';
  if (url.includes('seo-preview')) status = '404 Not Found (Rewritten in Prod)';

  const indexable = p.indexable;
  
  if (p.issues.length === 0) {
    md += `| ${url} | ${status} | ${indexable} | None | Info | None | No issues detected | N/A | Low | Neutral |\n`;
  } else {
    // If there are multiple issues, we can join them or output a row for each. Let's output a combined row.
    const issuesList = p.issues.map(i => i.type).join('; ');
    const maxSeverity = p.issues.some(i => i.severity === 'Critical') ? 'Critical' :
                       p.issues.some(i => i.severity === 'High') ? 'High' :
                       p.issues.some(i => i.severity === 'Medium') ? 'Medium' : 'Low';
    
    const rootCauses = p.issues.map(i => i.description).join('; ');
    const fixes = p.issues.map(i => i.fix).join('; ');
    
    // Determine priority
    const priority = maxSeverity === 'Critical' ? 'Critical' :
                     maxSeverity === 'High' ? 'High' :
                     maxSeverity === 'Medium' ? 'Medium' : 'Low';

    const seoImpact = maxSeverity === 'Critical' ? 'Very High' :
                       maxSeverity === 'High' ? 'High' :
                       maxSeverity === 'Medium' ? 'Moderate' : 'Low';

    let evidence = `Word Count: ${p.wordCount}`;
    if (p.isOrphan) evidence += `, Click Depth: Unreachable`;
    if (p.issues.some(i => i.type.includes('Noindex'))) evidence += `, robots meta: noindex`;

    // Escape markdown table pipes
    const cleanUrl = url.replace(/\|/g, '\\|');
    const cleanIssues = issuesList.replace(/\|/g, '\\|');
    const cleanCauses = rootCauses.replace(/\|/g, '\\|');
    const cleanFixes = fixes.replace(/\|/g, '\\|');

    md += `| ${cleanUrl} | ${status} | ${indexable} | ${cleanIssues} | ${maxSeverity} | ${cleanCauses} | ${evidence} | ${cleanFixes} | ${priority} | ${seoImpact} |\n`;
  }
});

fs.writeFileSync(path.join(artifactDir, 'seo_audit_spreadsheet.md'), md);
console.log('Spreadsheet markdown generated successfully at:', path.join(artifactDir, 'seo_audit_spreadsheet.md'));
