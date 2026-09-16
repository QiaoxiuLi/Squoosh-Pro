import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../contracts/', import.meta.url);

test('all contracts are JSON Schema 2020-12 with version fields', async () => {
  for (const name of ['preset.schema.json', 'codec-request.schema.json', 'codec-response.schema.json', 'job-report.schema.json']) {
    const schema = JSON.parse(await readFile(new URL(name, root), 'utf8'));
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
    assert.equal(schema.type, 'object');
    assert.ok(schema.required.includes('schemaVersion'));
    assert.equal(schema.properties.schemaVersion.const, 1);
  }
});

test('preset codec and strategy enums remain platform-neutral', async () => {
  const schema = JSON.parse(await readFile(new URL('preset.schema.json', root), 'utf8'));
  assert.deepEqual(schema.properties.output.properties.format.enum, ['automatic', 'mozjpeg', 'oxipng', 'webp', 'avif']);
  assert.deepEqual(schema.properties.output.properties.strategy.enum, ['fixedQuality', 'targetBytes']);
  assert.equal(JSON.stringify(schema).includes('/Users/'), false);
  const example = JSON.parse(await readFile(new URL('examples/web-jpeg-150kb.json', root), 'utf8'));
  assert.equal(example.output.targetBytes, 150000);
  assert.equal(example.output.safetyTargetBytes, 145000);
  assert.deepEqual(example.resize.candidateWidths, [1000, 960, 920]);
});
