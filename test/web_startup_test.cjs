const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/startup.js'), 'utf8');
const bootstrap = fs.readFileSync(path.join(__dirname, '../web/flutter_bootstrap.js'), 'utf8')
  .replace(/\{\{flutter_js\}\}|\{\{flutter_build_config\}\}/g, '');

for (const hostname of ['127.0.0.1', 'localhost', '[::1]', 'jotit.example']) {
  test(`bootstrap avoids stale preview code on ${hostname} without altering production caching`, () => {
    const build = {mainJsPath: 'main.dart.js'};
    let loads = 0;
    let config;
    vm.runInNewContext(bootstrap, {
      window: {location: {hostname}},
      document: {baseURI: `http://${hostname}/`, querySelector: () => ({})},
      URL,
      Date: {now: () => 12345},
      _flutter: {buildConfig: {builds: [build]}, loader: {load: (options) => {loads++; config = options.config;}}},
    });
    assert.equal(loads, 1);
    assert.equal(build.mainJsPath, hostname === 'jotit.example' ? 'main.dart.js' : 'main.dart.js?preview=12345');
    assert.equal(config.assetBase, hostname === 'jotit.example' ? undefined : `http://${hostname}/__jotit_preview/12345/`);
  });
}

test('ordinary local servers do not require the preview-only asset alias', () => {
  let config;
  vm.runInNewContext(bootstrap, {
    window: {location: {hostname: 'localhost'}},
    document: {baseURI: 'http://localhost/', querySelector: () => null},
    Date: {now: () => 12345},
    _flutter: {buildConfig: {builds: [{mainJsPath:'main.dart.js'}]}, loader: {load: (options) => {config=options.config;}}},
  });
  assert.equal(config.assetBase, undefined);
});

function createStartup(appearance, unavailable = false) {
  const elements = {
    startup: {hidden: false},
    'startup-message': {textContent: 'Loading your notes…'},
    'startup-retry': {hidden: true, addEventListener: (type, callback) => { retryClick = callback; }},
  };
  const handlers = new Map();
  let timeout;
  let retryClick;
  let reloads = 0;
  const root = {dataset: {}};
  vm.runInNewContext(source, {
    document: {getElementById: (id) => elements[id], documentElement: root},
    window: {
      localStorage: {getItem: () => { if (unavailable) throw new Error('Storage blocked'); return appearance; }},
      setTimeout: (callback) => { timeout = callback; return 1; },
      clearTimeout: () => { timeout = undefined; },
      addEventListener: (type, callback) => handlers.set(type, callback),
      location: {reload: () => { reloads++; }},
    },
  });
  return {
    elements,
    root,
    emit: (type) => handlers.get(type)(),
    runTimeout: () => timeout?.(),
    retry: () => retryClick(),
    get reloads() { return reloads; },
  };
}

test('loading remains visible until Flutter renders its first frame', () => {
  const startup = createStartup();
  assert.equal(startup.elements.startup.hidden, false);
  assert.equal(startup.elements['startup-retry'].hidden, true);
  startup.emit('flutter-first-frame');
  assert.equal(startup.elements.startup.hidden, true);
  startup.runTimeout();
  assert.equal(startup.elements['startup-retry'].hidden, true);
});

test('slow startup offers retry but a later first frame still opens the app', () => {
  const startup = createStartup();
  startup.runTimeout();
  assert.match(startup.elements['startup-message'].textContent, /longer than usual/);
  assert.equal(startup.elements['startup-retry'].hidden, false);
  startup.emit('flutter-first-frame');
  assert.equal(startup.elements.startup.hidden, true);
});

for (const event of ['error', 'unhandledrejection']) {
  test(`${event} shows a non-destructive startup failure`, () => {
    const startup = createStartup();
    startup.emit(event);
    assert.match(startup.elements['startup-message'].textContent, /could not start/);
    assert.match(startup.elements['startup-message'].textContent, /notes have not been cleared/);
    assert.equal(startup.elements['startup-retry'].hidden, false);
    startup.runTimeout();
    assert.match(startup.elements['startup-message'].textContent, /could not start/);
  });
}

test('runtime errors after startup do not cover the running app', () => {
  const startup = createStartup();
  startup.emit('flutter-first-frame');
  startup.emit('error');
  startup.emit('unhandledrejection');
  assert.equal(startup.elements.startup.hidden, true);
  assert.equal(startup.elements['startup-retry'].hidden, true);
});

test('retry reloads the page without clearing storage', () => {
  const startup = createStartup();
  startup.emit('error');
  startup.retry();
  assert.equal(startup.reloads, 1);
});

for (const appearance of ['light', 'dark', 'system']) {
  test(`startup restores the ${appearance} appearance mirror`, () => {
    assert.equal(createStartup(appearance).root.dataset.appearance, appearance);
  });
}

test('invalid or blocked appearance storage does not stop loading', () => {
  assert.equal(createStartup('invalid').root.dataset.appearance, undefined);
  const startup = createStartup('light', true);
  startup.emit('flutter-first-frame');
  assert.equal(startup.elements.startup.hidden, true);
});
