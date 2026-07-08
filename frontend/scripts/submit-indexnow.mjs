import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Root of build directory (relative to scripts/)
const distDir = path.resolve(__dirname, '../dist');
const sitemapPath = path.join(distDir, 'sitemap-0.xml');
const sitemapIndexPath = path.join(distDir, 'sitemap-index.xml');

async function run() {
  console.log('[IndexNow] Starting post-build URL submission...');

  // 1. Locate sitemap file containing page URLs
  let sitemapContent = '';
  if (fs.existsSync(sitemapPath)) {
    sitemapContent = fs.readFileSync(sitemapPath, 'utf8');
    console.log(`[IndexNow] Found sitemap-0.xml at ${sitemapPath}`);
  } else if (fs.existsSync(sitemapIndexPath)) {
    sitemapContent = fs.readFileSync(sitemapIndexPath, 'utf8');
    console.log(`[IndexNow] Found sitemap-index.xml at ${sitemapIndexPath}`);
  } else {
    console.warn('[IndexNow] No sitemap file found in build directory. Skipping submission.');
    return;
  }

  // 2. Extract URLs from sitemap
  const urlRegex = /<loc>(https?:\/\/[^<]+)<\/loc>/g;
  const urls = [];
  let match;
  while ((match = urlRegex.exec(sitemapContent)) !== null) {
    // Exclude sitemap-0.xml or search paths if any
    const url = match[1];
    if (!url.endsWith('.xml') && !url.includes('/search/')) {
      urls.push(url);
    }
  }

  if (urls.length === 0) {
    console.warn('[IndexNow] No eligible URLs found in sitemap. Skipping submission.');
    return;
  }

  console.log(`[IndexNow] Extracted ${urls.length} page URLs for submission.`);

  // 3. Prepare payload
  const payload = {
    host: 'mdupapers.com',
    key: 'c28763223d6040dba3448cf9a0c87ad6',
    keyLocation: 'https://mdupapers.com/c28763223d6040dba3448cf9a0c87ad6.txt',
    urlList: urls,
  };

  // 4. Send POST request to IndexNow API
  try {
    const response = await fetch('https://api.indexnow.org/indexnow', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify(payload),
    });

    if (response.status === 200) {
      console.log(`[IndexNow] Successfully submitted ${urls.length} URLs to Bing & IndexNow search engines!`);
    } else {
      const errorText = await response.text();
      console.error(`[IndexNow] API returned status ${response.status}: ${errorText}`);
    }
  } catch (error) {
    console.error('[IndexNow] Failed to ping IndexNow API:', error);
  }
}

run();
