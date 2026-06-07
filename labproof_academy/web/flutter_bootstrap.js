{{flutter_js}}
{{flutter_build_config}}

(function () {
  _flutter.loader.load({
    serviceWorkerSettings: null,
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine({
        renderer: "html"
      });
      await appRunner.runApp();
    },
  });
})();
