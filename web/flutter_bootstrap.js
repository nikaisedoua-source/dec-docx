{{flutter_js}}
{{flutter_build_config}}

(async () => {
  const appRoot = new URL('./', document.baseURI);
  // Retire only this application's old offline loader and compiled assets.
  // The document library lives in IndexedDB and is never cleared here.
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations
        .filter((registration) => registration.scope === appRoot.href)
        .map((registration) => registration.unregister()));
    }
    if ('caches' in window) {
      for (const name of await caches.keys()) {
        if (!name.startsWith('flutter-')) continue;
        const cache = await caches.open(name);
        for (const request of await cache.keys()) {
          const url = new URL(request.url);
          if (url.origin === appRoot.origin && url.pathname.startsWith(appRoot.pathname)) {
            await cache.delete(request);
          }
        }
      }
    }
  } catch (error) {
    console.warn('DEC DOCX: asset cache cleanup unavailable.', error);
  }
  // A build-specific asset URL avoids stale JavaScript at the canonical URL.
  for (const build of _flutter.buildConfig.builds) {
    if (build.compileTarget === 'dart2js') {
      const entrypoint = new URL(build.mainJsPath || 'main.dart.js', appRoot);
      entrypoint.searchParams.set('build', '1.9.15');
      build.mainJsPath = entrypoint.href;
    }
  }
  await _flutter.loader.load({config: {assetBase: 'releases/1.9.15/'}});
})();
