'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { updateReadmeImage } = require('./generate');

test('updates the matching README image with a content hash', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'commit-pet-'));
  const readme = path.join(directory, 'README.md');
  const image = path.join(directory, 'commit-pet.svg');
  fs.writeFileSync(readme, '# Profile\n\n![Boo](commit-pet.svg)\n');

  const version = updateReadmeImage(readme, image, '<svg>new pet</svg>');
  assert.match(version, /^[0-9a-f]{12}$/);
  assert.equal(
    fs.readFileSync(readme, 'utf8'),
    `# Profile\n\n![Boo](commit-pet.svg?v=${version})\n`,
  );
});

test('replaces an old query, preserves a fragment, and leaves other images alone', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'commit-pet-'));
  const readme = path.join(directory, 'README.md');
  const image = path.join(directory, 'assets', 'commit-pet.svg');
  fs.writeFileSync(
    readme,
    '![Avatar](avatar.png)\n![Boo](<assets/commit-pet.svg?v=old#pet> "Pet")\n',
  );

  const version = updateReadmeImage(readme, image, '<svg>changed</svg>');
  assert.equal(
    fs.readFileSync(readme, 'utf8'),
    `![Avatar](avatar.png)\n![Boo](<assets/commit-pet.svg?v=${version}#pet> "Pet")\n`,
  );
});

test('fails clearly when the README does not contain the generated image', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'commit-pet-'));
  const readme = path.join(directory, 'README.md');
  fs.writeFileSync(readme, '![Avatar](avatar.png)\n');

  assert.throws(
    () => updateReadmeImage(readme, path.join(directory, 'commit-pet.svg'), '<svg/>'),
    /No Markdown image/,
  );
});
