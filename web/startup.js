(() => {
  try {
    const appearance = window.localStorage.getItem('jotit.appearance');
    if (['light', 'dark', 'system'].includes(appearance)) document.documentElement.dataset.appearance = appearance;
  } catch (_) {}
  const startup = document.getElementById('startup');
  const message = document.getElementById('startup-message');
  const retry = document.getElementById('startup-retry');
  let ready = false;

  const showFailure = () => {
    if (ready) return;
    window.clearTimeout(slowStart);
    message.textContent = 'JotIt could not start. Check that the preview server is running, then try again. Your saved notes have not been cleared.';
    retry.hidden = false;
  };

  const slowStart = window.setTimeout(() => {
    if (ready) return;
    message.textContent = 'JotIt is taking longer than usual to start. You can keep waiting or try again.';
    retry.hidden = false;
  }, 20000);

  window.addEventListener('flutter-first-frame', () => {
    ready = true;
    window.clearTimeout(slowStart);
    startup.hidden = true;
  }, {once: true});
  window.addEventListener('error', showFailure, true);
  window.addEventListener('unhandledrejection', showFailure);
  retry.addEventListener('click', () => window.location.reload());
})();
