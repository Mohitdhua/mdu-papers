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
  // Only run in Cloudflare Pages production environment
  if (process.env.CF_PAGES && process.env.CF_PAGES_BRANCH !== 'main') {
    console.log('[IndexNow] Skipping submission for non-main branch (preview/dev build).');
    return;
  }

  if (!process.env.CF_PAGES) {
    console.log('[IndexNow] Skipping submission for local build (not in CF_PAGES environment).');
    return;
  }

  console.log('[IndexNow] Starting post-build URL submission...');

  // 1. Read sitemap-index.xml to find all sitemaps, or fallback to sitemap-0.xml
  const urls = [];
  const urlRegex = /<loc>(https?:\/\/[^<]+)<\/loc>/g;
  const sitemapFiles = [];

  if (fs.existsSync(sitemapIndexPath)) {
    console.log(`[IndexNow] Found sitemap-index.xml at ${sitemapIndexPath}`);
    const indexContent = fs.readFileSync(sitemapIndexPath, 'utf8');
    let indexMatch;
    while ((indexMatch = urlRegex.exec(indexContent)) !== null) {
      const sitemapUrl = indexMatch[1];
      const sitemapFilename = sitemapUrl.split('/').pop();
      if (sitemapFilename && sitemapFilename.endsWith('.xml')) {
        const fullPath = path.join(distDir, sitemapFilename);
        if (fs.existsSync(fullPath)) {
          sitemapFiles.push(fullPath);
        }
      }
    }
  } else if (fs.existsSync(sitemapPath)) {
    console.log(`[IndexNow] Found sitemap-0.xml at ${sitemapPath}`);
    sitemapFiles.push(sitemapPath);
  } else {
    console.warn('[IndexNow] No sitemap file found in build directory. Skipping submission.');
    return;
  }

  // 2. Extract URLs from all collected sitemaps
  for (const file of sitemapFiles) {
    const sitemapContent = fs.readFileSync(file, 'utf8');
    let match;
    while ((match = urlRegex.exec(sitemapContent)) !== null) {
      const url = match[1];
      if (!url.endsWith('.xml') && !url.includes('/search/')) {
        urls.push(url);
      }
    }
  }

  if (urls.length === 0) {
    console.warn('[IndexNow] No eligible URLs found in sitemap(s). Skipping submission.');
    return;
  }

  console.log(`[IndexNow] Extracted ${urls.length} page URLs for submission.`);

  // 3. Prepare payload and batch to 10k max
  const maxBatchSize = 10000;
  for (let i = 0; i < urls.length; i += maxBatchSize) {
    const batchUrls = urls.slice(i, i + maxBatchSize);
    const payload = {
      host: 'mdupapers.com',
      key: '10fdbcbbab33498c89f0e046e98a6b8e',
      keyLocation: 'https://mdupapers.com/10fdbcbbab33498c89f0e046e98a6b8e.txt',
      urlList: batchUrls,
    };

    // 4. Send POST request to IndexNow API
    try {
      console.log(`[IndexNow] Submitting batch ${Math.floor(i/maxBatchSize) + 1} (${batchUrls.length} URLs)...`);
      const response = await fetch('https://api.indexnow.org/indexnow', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify(payload),
      });

      if (response.status === 200 || response.status === 202) {
        console.log(`[IndexNow] Successfully submitted batch of ${batchUrls.length} URLs!`);
      } else {
        const errorText = await response.text();
        console.error(`[IndexNow] API returned status ${response.status}: ${errorText}`);
      }
    } catch (error) {
      console.error('[IndexNow] Failed to ping IndexNow API:', error);
    }
  }
}

run();
