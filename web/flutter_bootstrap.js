{{flutter_js}}
{{flutter_build_config}}

const previewConfig = {};
if (['127.0.0.1', 'localhost', '[::1]'].includes(window.location.hostname)) {
  const previewVersion = Date.now().toString();
  if (document.querySelector('meta[name="jotit-preview-assets"]')) {
    previewConfig.assetBase = new URL(`__jotit_preview/${previewVersion}/`, document.baseURI).toString();
  }
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      const separator = build.mainJsPath.includes('?') ? '&' : '?';
      build.mainJsPath += `${separator}preview=${previewVersion}`;
    }
  }
}

_flutter.loader.load({config: previewConfig});
