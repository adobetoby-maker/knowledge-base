# Batch: i18n Translation Sync

## Overview
Translation workflows fail when they are manual — developers add new keys, forget to notify
translators, and months later users see untranslated strings or placeholder keys. Automated
translation sync closes this loop: extract new keys daily, push missing ones to the translation
service, and pull completed translations back into the codebase automatically.

## Implementation

### Extract New Translation Keys from Codebase
```bash
# i18next-parser: extracts all translation keys from source code
npx i18next-parser --config i18next-parser.config.js

# i18next-parser.config.js
module.exports = {
  locales: ['en', 'es', 'fr', 'de', 'ja'],
  defaultLocale: 'en',
  output: 'public/locales/$LOCALE/$NAMESPACE.json',
  input: ['src/**/*.{ts,tsx}'],
  keySeparator: '.',
  namespaceSeparator: ':',
  keepRemoved: false,          // remove keys no longer in source
  createOldCatalogs: false,
  defaultValue: (locale, namespace, key) => {
    // For the default (source) locale, use the key as the value
    return locale === 'en' ? key : '';  // empty string = "needs translation"
  },
};
```

### Compare Against Existing Translations
```ts
import { readdir, readFile, writeFile } from 'fs/promises';
import path from 'path';

async function findMissingTranslations(localesDir: string): Promise<MissingTranslation[]> {
  const missing: MissingTranslation[] = [];

  const sourceLocale = await loadLocale(localesDir, 'en');
  const targetLocales = ['es', 'fr', 'de', 'ja'];

  for (const locale of targetLocales) {
    const existing = await loadLocale(localesDir, locale);

    for (const [namespace, keys] of Object.entries(sourceLocale)) {
      for (const [key, value] of Object.entries(keys)) {
        const translated = existing[namespace]?.[key];
        if (!translated || translated === '') {
          missing.push({ locale, namespace, key, sourceText: value as string });
        }
      }
    }
  }

  return missing;
}
```

### Push Missing Keys to Translation Service (Crowdin/Phrase)
```ts
// Crowdin API example
import Crowdin from '@crowdin/crowdin-api-client';

const crowdin = new Crowdin({ token: process.env.CROWDIN_API_TOKEN });

async function pushMissingKeysToCrowdin(missing: MissingTranslation[], projectId: number) {
  // Group by namespace (file) for batch upload
  const byNamespace = groupBy(missing, m => m.namespace);

  for (const [namespace, keys] of Object.entries(byNamespace)) {
    const sourceStrings = keys.map(k => ({
      identifier: k.key,
      text: k.sourceText,
      context: `Namespace: ${namespace}`,
    }));

    await crowdin.sourceStringsApi.addString(projectId, sourceStrings);
  }

  console.log(`Pushed ${missing.length} missing keys to Crowdin across ${Object.keys(byNamespace).length} namespaces`);
}
```

### Pull Completed Translations Back
```ts
async function pullCompletedTranslationsFromCrowdin(projectId: number, localesDir: string) {
  const buildId = await crowdin.translationsApi.buildProjectTranslation(projectId, {
    skipUntranslatedStrings: true,  // don't include untranslated strings in download
  });

  // Wait for build to complete
  let build;
  do {
    await sleep(3000);
    build = await crowdin.translationsApi.checkBuildStatus(projectId, buildId.data.id);
  } while (build.data.status !== 'finished');

  // Download and write to disk
  const downloadLink = await crowdin.translationsApi.downloadTranslations(projectId, buildId.data.id);
  const zipContent = await fetch(downloadLink.data.url).then(r => r.arrayBuffer());
  await extractZipToLocalesDir(zipContent, localesDir);

  console.log('Translations pulled from Crowdin');
}
```

### Generate Diff of Missing Keys Per Locale
```ts
async function reportTranslationStatus() {
  const missing = await findMissingTranslations('./public/locales');

  const byLocale = groupBy(missing, m => m.locale);
  const report = Object.entries(byLocale).map(([locale, keys]) => ({
    locale,
    missingCount: keys.length,
    namespaces: [...new Set(keys.map(k => k.namespace))],
  }));

  // Log to console for CI visibility
  for (const { locale, missingCount } of report) {
    console.log(`${locale}: ${missingCount} keys missing`);
  }

  // Alert if any locale falls below 80% completion
  for (const { locale, missingCount } of report) {
    const totalKeys = await countTotalKeys('./public/locales/en');
    const completionPct = 100 - (missingCount / totalKeys * 100);
    if (completionPct < 80) {
      await slack.send(`Translation alert: ${locale} is at ${completionPct.toFixed(1)}% completion`);
    }
  }
}
```

## Key Rules
- Run `i18next-parser` as a pre-commit hook and in CI — untranslated keys in source are a build artifact
- `keepRemoved: false` in parser config removes stale keys from locale files — prevents dead translations accumulating
- Push keys in batches by namespace to translation services — per-key pushes exhaust API rate limits
- Never commit machine-translated content without human review — use the translation service's workflow, not auto-translation APIs
- Track completion percentage per locale; alert when a locale drops below 80% (common after feature releases)
- Pull translations on a schedule (nightly), not on demand — avoids blocking deploys on translation service availability
- Store locale files in version control — the translation service is authoritative, but git is the backup
