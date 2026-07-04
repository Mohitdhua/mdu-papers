const fs = require('fs');
const path = require('path');

const rawDataPath = path.join(__dirname, 'audit_raw.json');
if (!fs.existsSync(rawDataPath)) {
  console.error('audit_raw.json not found. Run seo-audit-crawler.js first.');
  process.exit(1);
}

const pages = JSON.parse(fs.readFileSync(rawDataPath, 'utf8'));

// Helper to normalize paths/URLs for comparison
function normalizeUrl(url) {
  if (!url) return '';
  let u = url.trim();
  // Remove domain
  u = u.replace(/^https?:\/\/(www\.)?mdupapers\.com/, '');
  u = u.replace(/^https?:\/\/(www\.)?mdupyq\.com/, '');
  u = u.replace(/^https?:\/\/[\w-]+\.pages\.dev/, '');
  
  // Strip trailing hash/query
  u = u.split('#')[0].split('?')[0];
  
  // Ensure starts and ends with slash
  if (!u.startsWith('/')) u = '/' + u;
  if (!u.endsWith('/') && !u.includes('.')) u = u + '/';
  
  return u;
}

const pageUrls = new Set(pages.map(p => normalizeUrl(p.pageUrl)));
const pageMap = new Map(pages.map(p => [normalizeUrl(p.pageUrl), p]));

// Click Depth & Internal Links Calculation (BFS)
const incomingLinks = new Map(); // child -> Set of parents
const clickDepth = new Map();    // url -> depth
const outgoingLinksCount = new Map(); // url -> count
const brokenLinks = []; // array of { from, to, anchorText }

// Initialize maps
pages.forEach(p => {
  const norm = normalizeUrl(p.pageUrl);
  incomingLinks.set(norm, new Set());
  clickDepth.set(norm, Infinity);
  outgoingLinksCount.set(norm, 0);
});

// BFS for Click Depth starting from homepage
const queue = ['/'];
clickDepth.set('/', 0);

while (queue.length > 0) {
  const current = queue.shift();
  const currentDepth = clickDepth.get(current);
  const currentPage = pageMap.get(current);
  
  if (!currentPage) continue;
  
  currentPage.links.forEach(link => {
    // Resolve relative path/absolute path
    let target = link.href;
    if (target.startsWith('http') && !target.includes('mdupapers.com') && !target.includes('mdupyq.com')) {
      // External link
      return;
    }
    
    const normTarget = normalizeUrl(target);
    if (!normTarget || normTarget.startsWith('mailto:') || normTarget.startsWith('tel:')) return;
    
    // Count outgoing
    outgoingLinksCount.set(current, (outgoingLinksCount.get(current) || 0) + 1);
    
    if (pageUrls.has(normTarget)) {
      // Record incoming link
      incomingLinks.get(normTarget).add(current);
      
      // BFS Depth update
      if (clickDepth.get(normTarget) === Infinity) {
        clickDepth.set(normTarget, currentDepth + 1);
        queue.push(normTarget);
      }
    } else {
      // Check if it is a asset or just a broken link
      if (!normTarget.includes('.') && !normTarget.startsWith('#') && normTarget !== '/search-index.json' && normTarget !== '/seo-index.json') {
        brokenLinks.push({
          from: current,
          to: link.href,
          norm: normTarget
        });
      }
    }
  });
}

// Check other pages (not reached by BFS) for links
pages.forEach(p => {
  const norm = normalizeUrl(p.pageUrl);
  if (clickDepth.get(norm) === Infinity) {
    // Not reached by homepage BFS, but let's check its links anyway to populate incomingLinks
    p.links.forEach(link => {
      let target = link.href;
      if (target.startsWith('http') && !target.includes('mdupapers.com') && !target.includes('mdupyq.com')) return;
      const normTarget = normalizeUrl(target);
      if (!normTarget || normTarget.startsWith('mailto:') || normTarget.startsWith('tel:')) return;
      
      if (pageUrls.has(normTarget)) {
        incomingLinks.get(normTarget).add(norm);
      }
    });
  }
});

// Title & Description Duplicates Checking
const titlesMap = new Map();
const descsMap = new Map();
const h1sMap = new Map();

pages.forEach(p => {
  if (p.title) {
    if (!titlesMap.has(p.title)) titlesMap.set(p.title, []);
    titlesMap.get(p.title).push(p.pageUrl);
  }
  if (p.description) {
    if (!descsMap.has(p.description)) descsMap.set(p.description, []);
    descsMap.get(p.description).push(p.pageUrl);
  }
  p.h1s.forEach(h1 => {
    if (!h1sMap.has(h1)) h1sMap.set(h1, []);
    h1sMap.get(h1).push(p.pageUrl);
  });
});

// Analyze individual pages
const auditedPages = pages.map(p => {
  const norm = normalizeUrl(p.pageUrl);
  const depth = clickDepth.get(norm);
  const inc = incomingLinks.get(norm) ? Array.from(incomingLinks.get(norm)) : [];
  const outCount = outgoingLinksCount.get(norm) || 0;
  
  const issues = [];
  
  // 1. Indexability
  const isNoindex = p.robots.toLowerCase().includes('noindex');
  let indexable = isNoindex ? 'No' : 'Yes';
  
  if (isNoindex) {
    issues.push({
      category: 'Indexing',
      type: 'Noindex Tag Found',
      severity: 'Low', // usually intentional
      description: 'Page has a meta robots noindex tag preventing Google indexing.',
      fix: 'If this page should be crawled and ranked, remove the noindex tag.'
    });
  }

  // 2. Canonical Check
  let canonicalMismatch = false;
  if (!p.canonical) {
    issues.push({
      category: 'Canonicalization',
      type: 'Missing Canonical Tag',
      severity: 'Medium',
      description: 'The page lacks a canonical link declaration.',
      fix: 'Add a self-referencing canonical tag.'
    });
  } else {
    // Check if canonical contains mdupyq.com
    if (p.canonical.includes('mdupyq.com')) {
      issues.push({
        category: 'Canonicalization',
        type: 'Wrong Domain in Canonical URL',
        severity: 'Critical',
        description: `Canonical URL points to the legacy domain 'mdupyq.com' instead of production 'mdupapers.com'.`,
        fix: `Update configuration (e.g. PUBLIC_SITE_URL or SITE.url) to point to 'https://mdupapers.com'.`
      });
      canonicalMismatch = true;
    }
    
    // Check if canonical points to a different path
    const normCanonical = normalizeUrl(p.canonical);
    if (normCanonical !== norm && !isNoindex) {
      issues.push({
        category: 'Canonicalization',
        type: 'Canonical Path Mismatch',
        severity: 'High',
        description: `Page at ${norm} canonicalizes to ${normCanonical}, making it a non-canonical page.`,
        fix: `Ensure self-referencing canonical is set if this is a unique page, or redirect if it is a duplicate.`
      });
      canonicalMismatch = true;
    }
  }

  // 3. Title Check
  if (!p.title) {
    issues.push({
      category: 'On-Page SEO',
      type: 'Missing Title Tag',
      severity: 'Critical',
      description: 'Page lacks a <title> element.',
      fix: 'Add a unique, keyword-rich title between 50-60 characters.'
    });
  } else if (titlesMap.get(p.title).length > 1 && !isNoindex) {
    issues.push({
      category: 'On-Page SEO',
      type: 'Duplicate Title Tag',
      severity: 'High',
      description: `Title is identical to ${titlesMap.get(p.title).length - 1} other page(s).`,
      fix: 'Write a unique title that accurately describes this specific page.'
    });
  }

  // 4. Description Check
  if (!p.description) {
    issues.push({
      category: 'On-Page SEO',
      type: 'Missing Meta Description',
      severity: 'High',
      description: 'Page lacks a meta description.',
      fix: 'Add a unique, CTR-focused meta description between 120-160 characters.'
    });
  } else if (descsMap.get(p.description).length > 1 && !isNoindex) {
    // Only flag if description is not a default site description
    if (p.description !== 'Download free MDU previous year exam papers and study notes for BCA, B.Tech, BSc, BCom, MBA, MCA and all courses. Updated papers from 2015-2024.') {
      issues.push({
        category: 'On-Page SEO',
        type: 'Duplicate Meta Description',
        severity: 'Medium',
        description: `Meta description is identical to ${descsMap.get(p.description).length - 1} other page(s).`,
        fix: 'Write a custom description representing this page\'s unique content.'
      });
    } else {
      issues.push({
        category: 'On-Page SEO',
        type: 'Default Site Meta Description Used',
        severity: 'Medium',
        description: 'Page uses the fallback home page description.',
        fix: 'Define custom meta descriptions for all courses and semesters.'
      });
    }
  }

  // 5. H1 Check
  if (p.h1s.length === 0) {
    issues.push({
      category: 'On-Page SEO',
      type: 'Missing H1 Tag',
      severity: 'High',
      description: 'Page lacks a main <h1> heading.',
      fix: 'Add exactly one <h1> heading containing target keywords.'
    });
  } else if (p.h1s.length > 1) {
    issues.push({
      category: 'On-Page SEO',
      type: 'Multiple H1 Tags',
      severity: 'Medium',
      description: `Page contains ${p.h1s.length} <h1> tags. Heading hierarchy is broken.`,
      fix: 'Consolidate headings so there is only one <h1>, and demote others to <h2> or <h3>.'
    });
  }

  // 6. Content Quality
  if (p.wordCount < 250 && !isNoindex) {
    issues.push({
      category: 'Content Quality',
      type: 'Thin Content',
      severity: 'High',
      description: `Word count is very low (${p.wordCount} words). Google might classify this as low quality or soft 404.`,
      fix: 'Expand the page content with detailed subject descriptions, syllabus information, or FAQs.'
    });
  }

  // 7. Images Alt Checking
  const missingAltCount = p.images.filter(img => !img.alt || img.alt.trim() === '').length;
  if (missingAltCount > 0) {
    issues.push({
      category: 'Accessibility & Image SEO',
      type: 'Missing Alt Attributes',
      severity: 'Low',
      description: `${missingAltCount} image(s) lack an alt attribute or have an empty one.`,
      fix: 'Add descriptive alt text to all img elements for screen readers and search bots.'
    });
  }

  // 8. Sitemap inclusion check
  if (!p.inSitemap && !isNoindex) {
    issues.push({
      category: 'Sitemap',
      type: 'Indexable Page Missing from Sitemap',
      severity: 'High',
      description: 'Page is indexable but not listed in sitemap-0.xml.',
      fix: 'Ensure this route is captured in the sitemap generation integration config.'
    });
  } else if (p.inSitemap && isNoindex) {
    issues.push({
      category: 'Sitemap',
      type: 'Non-Indexable Page in Sitemap',
      severity: 'Medium',
      description: 'Page is blocked by noindex but still included in the sitemap.',
      fix: 'Remove non-indexable routes from the sitemap-0.xml.'
    });
  }

  // 9. Schema Checks
  const hasFAQ = p.schemas.some(s => s['@type'] === 'FAQPage' || (s['@graph'] && s['@graph'].some(g => g['@type'] === 'FAQPage')));
  const hasCourse = p.schemas.some(s => s['@type'] === 'Course' || (s['@graph'] && s['@graph'].some(g => g['@type'] === 'Course')));
  const hasCollection = p.schemas.some(s => s['@type'] === 'CollectionPage' || (s['@graph'] && s['@graph'].some(g => g['@type'] === 'CollectionPage')));
  const hasBreadcrumb = p.schemas.some(s => s['@type'] === 'BreadcrumbList' || (s['@graph'] && s['@graph'].some(g => g['@type'] === 'BreadcrumbList')));

  if (p.relativePath.includes('[semester]') && !hasFAQ) {
    issues.push({
      category: 'Structured Data',
      type: 'Missing FAQ Schema',
      severity: 'Low',
      description: 'Semester page has FAQs but is missing FAQPage structured data.',
      fix: 'Add structured JSON-LD FAQPage markup.'
    });
  }

  // Orphan Check
  const isOrphan = inc.length === 0 && norm !== '/';
  if (isOrphan && !isNoindex) {
    issues.push({
      category: 'Internal Linking',
      type: 'Orphan Page',
      severity: 'High',
      description: 'Page has 0 internal incoming links from other pages.',
      fix: 'Link to this page from the homepage, header, footer, or other relevant category pages.'
    });
  }

  return {
    url: p.pageUrl,
    relativePath: p.relativePath,
    title: p.title,
    wordCount: p.wordCount,
    indexable,
    depth: depth === Infinity ? 'Unreachable' : depth,
    incomingLinksCount: inc.length,
    outgoingLinksCount: outCount,
    isOrphan,
    issues
  };
});

// Process broken links to attach to source pages
const sourceBrokenLinks = new Map();
brokenLinks.forEach(bl => {
  if (!sourceBrokenLinks.has(bl.from)) sourceBrokenLinks.set(bl.from, []);
  sourceBrokenLinks.get(bl.from).push(bl.to);
});

auditedPages.forEach(ap => {
  const norm = normalizeUrl(ap.url);
  if (sourceBrokenLinks.has(norm)) {
    const targets = sourceBrokenLinks.get(norm);
    ap.issues.push({
      category: 'Internal Linking',
      type: 'Broken Internal Link(s)',
      severity: 'Critical',
      description: `Page contains links to non-existent internal URLs: ${targets.join(', ')}`,
      fix: `Correct the href attributes or remove the links.`
    });
  }
});

// Compile overall statistics
let totalIssues = 0;
const issuesCountByType = {};
const severityCount = { Critical: 0, High: 0, Medium: 0, Low: 0 };

auditedPages.forEach(ap => {
  ap.issues.forEach(i => {
    totalIssues++;
    issuesCountByType[i.type] = (issuesCountByType[i.type] || 0) + 1;
    severityCount[i.severity]++;
  });
});

const report = {
  totalCompiledPages: auditedPages.length,
  totalIssues,
  severityCount,
  issuesCountByType,
  brokenLinksTotal: brokenLinks.length,
  orphansCount: auditedPages.filter(p => p.isOrphan).length,
  nonIndexableCount: auditedPages.filter(p => p.indexable === 'No').length,
  pages: auditedPages
};

fs.writeFileSync(path.join(__dirname, 'audit_report.json'), JSON.stringify(report, null, 2));
console.log('Report analysis completed and saved to audit_report.json');
console.log('Severity counts:', severityCount);
console.log('Orphan pages:', report.orphansCount);
console.log('Broken links count:', report.brokenLinksTotal);
