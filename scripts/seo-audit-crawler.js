const fs = require('fs');
const path = require('path');

const distPath = path.resolve(__dirname, '../frontend/dist');
const siteUrl = 'https://mdupapers.com';

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    if (isDirectory) {
      walkDir(dirPath, callback);
    } else {
      callback(dirPath);
    }
  });
}

// Read Sitemap
let sitemapUrls = new Set();
try {
  const sitemapPath = path.join(distPath, 'sitemap-0.xml');
  if (fs.existsSync(sitemapPath)) {
    const sitemapContent = fs.readFileSync(sitemapPath, 'utf8');
    const locRegex = /<loc>(.*?)<\/loc>/g;
    let match;
    while ((match = locRegex.exec(sitemapContent)) !== null) {
      sitemapUrls.add(match[1].trim());
    }
  }
} catch (e) {
  console.error('Error reading sitemap:', e);
}

const auditResults = [];
const allPages = [];

walkDir(distPath, (filePath) => {
  if (!filePath.endsWith('.html')) return;
  
  const relativePath = path.relative(distPath, filePath);
  let pageUrl = siteUrl + '/' + relativePath.replace(/\\/g, '/');
  if (pageUrl.endsWith('index.html')) {
    pageUrl = pageUrl.substring(0, pageUrl.length - 10);
  }
  
  const content = fs.readFileSync(filePath, 'utf8');
  allPages.push({ filePath, relativePath, pageUrl, content });
});

console.log(`Found ${allPages.length} HTML pages in dist.`);

// Process pages
allPages.forEach(({ filePath, relativePath, pageUrl, content }) => {
  // Extract Title
  let title = '';
  const titleMatch = content.match(/<title>([^]*?)<\/title>/i);
  if (titleMatch) {
    title = titleMatch[1].trim();
  }

  // Extract Description
  let description = '';
  const descMatch = content.match(/<meta\s+name=["']description["']\s+content=["']([^]*?)["']/i) ||
                    content.match(/<meta\s+content=["']([^]*?)["']\s+name=["']description["']/i);
  if (descMatch) {
    description = descMatch[1].trim();
  }

  // Extract Canonical
  let canonical = '';
  const canonicalMatch = content.match(/<link\s+rel=["']canonical["']\s+href=["']([^]*?)["']/i) ||
                         content.match(/<link\s+href=["']([^]*?)["']\s+rel=["']canonical["']/i);
  if (canonicalMatch) {
    canonical = canonicalMatch[1].trim();
  }

  // Extract Robots meta
  let robots = '';
  const robotsMatch = content.match(/<meta\s+name=["']robots["']\s+content=["']([^]*?)["']/i);
  if (robotsMatch) {
    robots = robotsMatch[1].trim();
  }

  // Extract H1s
  const h1s = [];
  const h1Regex = /<h1[^>]*>([^]*?)<\/h1>/gi;
  let h1Match;
  while ((h1Match = h1Regex.exec(content)) !== null) {
    // strip HTML tags
    h1s.push(h1Match[1].replace(/<[^>]*>/g, '').trim());
  }

  // Extract all links
  const links = [];
  const linkRegex = /<a\s+[^>]*href=["']([^]*?)["']/gi;
  let linkMatch;
  while ((linkMatch = linkRegex.exec(content)) !== null) {
    let href = linkMatch[1].trim();
    // Get raw link element to check rel
    const startIdx = linkMatch.index;
    const endIdx = content.indexOf('>', startIdx);
    const aTag = content.substring(startIdx, endIdx + 1);
    const relMatch = aTag.match(/rel=["']([^]*?)["']/i);
    const rel = relMatch ? relMatch[1] : '';
    links.push({ href, rel });
  }

  // Extract Images and check Alt
  const images = [];
  const imgRegex = /<img\s+([^>]*?)>/gi;
  let imgMatch;
  while ((imgMatch = imgRegex.exec(content)) !== null) {
    const attrs = imgMatch[1];
    const srcMatch = attrs.match(/src=["']([^]*?)["']/i);
    const altMatch = attrs.match(/alt=["']([^]*?)["']/i);
    const src = srcMatch ? srcMatch[1] : '';
    const alt = altMatch ? altMatch[1] : null;
    images.push({ src, alt });
  }

  // Word Count of text in body
  let bodyText = '';
  const bodyMatch = content.match(/<body[^>]*>([^]*?)<\/body>/i);
  if (bodyMatch) {
    bodyText = bodyMatch[1]
      .replace(/<script[^>]*>[^]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[^]*?<\/style>/gi, '')
      .replace(/<[^>]*>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }
  const wordCount = bodyText ? bodyText.split(/\s+/).length : 0;

  // Count schemas
  const schemas = [];
  const schemaRegex = /<script\s+type=["']application\/ld\+json["'][^>]*>([^]*?)<\/script>/gi;
  let schemaMatch;
  while ((schemaMatch = schemaRegex.exec(content)) !== null) {
    try {
      const parsed = JSON.parse(schemaMatch[1].trim());
      schemas.push(parsed);
    } catch (e) {
      schemas.push({ error: 'Invalid JSON', raw: schemaMatch[1].substring(0, 100) });
    }
  }

  auditResults.push({
    pageUrl,
    relativePath,
    title,
    description,
    canonical,
    robots,
    h1s,
    links,
    images,
    wordCount,
    schemas,
    inSitemap: sitemapUrls.has(pageUrl) || sitemapUrls.has(pageUrl + '/') || sitemapUrls.has(pageUrl.replace(/\/$/, ''))
  });
});

fs.writeFileSync(path.join(__dirname, 'audit_raw.json'), JSON.stringify(auditResults, null, 2));
console.log('Audit completed and saved to audit_raw.json');
