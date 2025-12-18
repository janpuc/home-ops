if (window.location.pathname === '/') {
  const html = document.documentElement.outerHTML;
  localStorage.setItem('homepage_cache', html);
  localStorage.setItem('homepage_cache_time', Date.now());
  window.addEventListener('load', function() {
    const cached = localStorage.getItem('homepage_cache');
    const cacheTime = localStorage.getItem('homepage_cache_time');
    if (cached && cacheTime && (Date.now() - cacheTime < 3600000)) {
      const searchInput = document.querySelector('input[type="search"]');
      if (searchInput) {
        searchInput.focus();
        searchInput.select();
      }
    }
  });
}
