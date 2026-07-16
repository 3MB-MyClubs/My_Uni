import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join, normalize, relative, resolve } from 'node:path';

const projectRoot = process.cwd();
const siteRoot = resolve(projectRoot, 'docs');
const placeholder = 'SUPPORT_EMAIL_REPLACE_ME';
const allowPlaceholder = process.env.ALLOW_SUPPORT_EMAIL_PLACEHOLDER === '1';

const requiredFiles = [
  'index.html',
  'support/index.html',
  'privacy/index.html',
  'delete-account/index.html',
  'tr/index.html',
  'tr/support/index.html',
  'tr/privacy/index.html',
  'tr/delete-account/index.html',
  '404.html',
  'assets/styles.css',
  'assets/app-icon.png',
  'assets/og.png',
  '.nojekyll',
];

const errors = [];

for (const file of requiredFiles) {
  if (!existsSync(join(siteRoot, file))) errors.push(`Missing required file: docs/${file}`);
}

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}

function localTarget(sourceFile, rawUrl) {
  const cleanUrl = rawUrl.split('#')[0].split('?')[0];
  if (!cleanUrl || /^(?:https?:|mailto:|tel:|data:)/i.test(cleanUrl)) return null;

  const decoded = decodeURIComponent(cleanUrl);
  const target = decoded.startsWith('/My_Uni/')
    ? join(siteRoot, decoded.slice('/My_Uni/'.length))
    : decoded === '/My_Uni'
      ? siteRoot
      : resolve(dirname(sourceFile), decoded);

  let normalizedTarget = normalize(target);
  if (!extname(normalizedTarget) || normalizedTarget.endsWith('/')) {
    normalizedTarget = join(normalizedTarget, 'index.html');
  }
  return normalizedTarget;
}

if (existsSync(siteRoot)) {
  const siteFiles = walk(siteRoot);
  const htmlFiles = siteFiles.filter((file) => file.endsWith('.html'));

  for (const file of htmlFiles) {
    const html = readFileSync(file, 'utf8');
    const label = `docs/${relative(siteRoot, file)}`;

    if (!allowPlaceholder && html.includes(placeholder)) {
      errors.push(`${label} still contains the public support-email placeholder.`);
    }

    for (const match of html.matchAll(/(?:href|src)=["']([^"']+)["']/gi)) {
      const target = localTarget(file, match[1]);
      if (target && !existsSync(target)) {
        errors.push(`${label} links to missing local file: ${match[1]}`);
      }
    }

    if (!/<title>[^<]+<\/title>/i.test(html)) errors.push(`${label} has no page title.`);
    if (!/<meta\s+name=["']description["']/i.test(html) && !file.endsWith('404.html')) {
      errors.push(`${label} has no meta description.`);
    }
  }

  const ogImage = join(siteRoot, 'assets/og.png');
  if (existsSync(ogImage) && statSync(ogImage).size > 2_500_000) {
    errors.push('docs/assets/og.png is larger than 2.5 MB.');
  }
}

if (errors.length > 0) {
  console.error(`GitHub Pages validation failed:\n- ${errors.join('\n- ')}`);
  process.exit(1);
}

console.log('GitHub Pages validation passed.');
