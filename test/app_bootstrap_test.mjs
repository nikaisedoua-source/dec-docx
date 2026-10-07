import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const script = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

test('canonical app retires only its asset cache and loads current compiled code', async () => {
  const deleted = [];
  const unregistered = [];
  const opened = [];
  let loads = 0;
  let configuration;
  const appRoot = 'https://nikaisedoua-source.github.io/dec-docx/';
  const requests = [appRoot + 'main.dart.js', 'https://nikaisedoua-source.github.io/other/main.dart.js'];
  const caches = {
    keys: async () => ['flutter-app-cache', 'document-library'],
    open: async (name) => {
      opened.push(name);
      return {keys: async () => requests.map((url) => ({url})), delete: async (request) => deleted.push(request.url)};
    },
  };
  const flutter = {buildConfig: {builds: [{compileTarget: 'dart2js', mainJsPath: 'main.dart.js'}]},
    loader: {load: async (options) => { loads++; configuration = options.config; }}};
  await vm.runInNewContext(script, {URL, console, document: {baseURI: appRoot},
    window: {caches}, caches, _flutter: flutter,
    navigator: {serviceWorker: {getRegistrations: async () => [appRoot, 'https://nikaisedoua-source.github.io/other/']
      .map((scope) => ({scope, unregister: async () => unregistered.push(scope)}))}},
  });
  assert.deepEqual(unregistered, [appRoot]);
  assert.deepEqual(opened, ['flutter-app-cache']);
  assert.deepEqual(deleted, [requests[0]]);
  assert.equal(loads, 1);
  assert.equal(configuration.assetBase, 'releases/1.9.17/');
  assert.equal(flutter.buildConfig.builds[0].mainJsPath, appRoot + 'main.dart.js?build=1.9.17');
});

test('unavailable cache cleanup never prevents app startup', async () => {
  let loaded = false;
  await vm.runInNewContext(script, {URL, console: {warn() {}}, window: {},
    document: {baseURI: 'https://nikaisedoua-source.github.io/dec-docx/'},
    navigator: {serviceWorker: {getRegistrations: async () => {throw new Error('unavailable');}}},
    _flutter: {buildConfig: {builds: [{compileTarget: 'dart2js'}]}, loader: {load: async () => {loaded = true;}}},
  });
  assert.equal(loaded, true);
});

test('old version links become the canonical URL without dropping other state', () => {
  const index = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
  const inline = index.match(/<body>\s*<script>([\s\S]*?)<\/script>/)[1];
  let target;
  vm.runInNewContext(inline, {URL,
    window: {location: {href: 'https://nikaisedoua-source.github.io/dec-docx/?v=1.9.6&mode=local#test'}},
    history: {replaceState: (_state, _title, url) => {target=url;}},
  });
  assert.equal(target, '/dec-docx/?mode=local#test');
});
