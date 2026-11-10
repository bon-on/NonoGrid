{{flutter_js}}
{{flutter_build_config}}

// Render into #flutter-host so Flutter sizes itself to the area below the
// hub navigation bar instead of the full window (see index.html).
var engineStarted = false;
function startFlutter(config) {
  return _flutter.loader.load({
    config: config,
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      engineStarted = true;
      try {
        const appRunner = await engineInitializer.initializeEngine({
          hostElement: document.querySelector('#flutter-host'),
        });
        await appRunner.runApp();
      } catch (error) {
        console.error('Flutter engine failed to start', error);
      }
    },
  });
}

// Portal builds ship a WebAssembly build (used by Chromium browsers) and the
// JavaScript/CanvasKit build as the fallback (feature-portal-quality-pass).
// If the WebAssembly path fails before the engine starts (for example a host
// that serves .mjs with a wrong MIME type), retry once with the JavaScript
// build instead of showing a blank page. Never retry once an engine exists,
// so two engines never share #flutter-host.
startFlutter({}).catch(function (error) {
  if (engineStarted) {
    console.error('Flutter start failed', error);
    return;
  }
  console.warn('Flutter start failed, retrying with the JavaScript build', error);
  return startFlutter({ renderer: 'canvaskit' });
});
