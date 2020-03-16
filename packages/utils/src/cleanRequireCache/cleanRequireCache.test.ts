import { join } from 'path';
import cleanRequireCache from './cleanRequireCache';
import Module from 'module';

const base = join(__dirname, 'fixtures', 'normal');

test('normal', () => {
  const path = join(base, 'a.js');
  expect(require(path)()).toBe(1);
  expect(require(path)()).toBe(2);
  expect(require(path)()).toBe(3);

  cleanRequireCache(path);
  expect(require(path)()).toBe(1);

  cleanRequireCache(path);
  expect(require(path)()).toBe(1);
  expect(require(path)()).toBe(2);
});

test('clearNotExistCache', () => {
  // not throw Error when clearing one cache that not be existed
  expect(cleanRequireCache('somethingNotExist')).toBeUndefined();
});

test('clearCacheWithParent', () => {
  const s = join(base, 'a.js');
  const another = join(base, 'b.js');

  require(s);
  expect(require.cache[s].parent).toBeDefined();

  const children = require.cache[s].parent!.children;
  expect(children.length).toBeGreaterThan(0);
  expect(
    children.filter((module: Module) => module.id.includes('a.js')).length,
  ).toBeGreaterThan(0);

  require(another);
  cleanRequireCache(s);

  expect(require.cache[s]).toBeUndefined();
  // a.js should be clear in children, but b.js has to stay.
  expect(children.length).toBeGreaterThan(0);
  expect(
    children.filter((module: Module) => module.id.includes('a.js')).length,
  ).toBe(0);
});
