(() => {
  if (!('serviceWorker' in navigator)) return;

  window.addEventListener('load', async () => {
    try {
      const reg = await navigator.serviceWorker.register('/sw.js', {
        scope: '/',
      });

      if (reg.navigationPreload) {
        await reg.navigationPreload.enable();
      }
    } catch (err) {
      console.error('Service Worker registration failed:', err);
    }
  });
})();
