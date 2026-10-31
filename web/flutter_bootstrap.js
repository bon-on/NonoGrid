{{flutter_js}}
{{flutter_build_config}}

// Render into #flutter-host so Flutter sizes itself to the area below the
// hub navigation bar instead of the full window (see index.html).
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.querySelector('#flutter-host'),
    });
    await appRunner.runApp();
  },
});
