{{flutter_js}}
{{flutter_build_config}}

(function () {
  const host = window.location.hostname;
  const isLocalPreviewHost =
    host === '127.0.0.1' || host === 'localhost' || host === '::1';

  _flutter.loader.load({
    serviceWorkerSettings: isLocalPreviewHost
        ? null
        : {
            serviceWorkerVersion: {{flutter_service_worker_version}},
          },
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine({
        renderer: "html"
      });
      await appRunner.runApp();
    },
  });
})();
