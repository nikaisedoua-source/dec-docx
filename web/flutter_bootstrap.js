{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=1.8.0`;
  }
}

_flutter.loader.load();
