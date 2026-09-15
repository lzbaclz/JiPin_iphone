import qrcode from './assets/vendor/qrcode-generator/qrcode.mjs?v=2.0.4';

// Buttons, QR codes and copy actions must use exactly the same destination.
export function publicDownloadURL(value, kind) {
  try {
    const url = new URL(value);
    const validPath = kind === 'app-store'
      ? url.hostname === 'apps.apple.com' && /^\/(?:[a-z]{2}\/)?app\/(?:[^/]+\/)?id\d+\/?$/.test(url.pathname)
      : kind === 'testflight' && url.hostname === 'testflight.apple.com' && /^\/join\/[a-zA-Z0-9]+\/?$/.test(url.pathname);
    if (url.protocol !== 'https:' || url.port || url.username || url.password || !validPath) return null;
    return `${url.origin}${url.pathname.replace(/\/$/, '')}`;
  } catch { return null; }
}

export function qrMatrix(url) {
  const qr = qrcode(0, 'M');
  qr.addData(url, 'Byte');
  qr.make();
  const count = qr.getModuleCount();
  return Array.from({ length: count }, (_, row) => Array.from({ length: count }, (_, col) => qr.isDark(row, col)));
}

export function mountDownloadLinks(config) {
  const entries = [['app-store', config.appStoreURL], ['testflight', config.testFlightURL]];
  let enabled = 0;
  for (const [kind, value] of entries) {
    const card = document.querySelector(`#${kind}-invitation`);
    const url = publicDownloadURL(value, kind);
    card.hidden = !url;
    const links = document.querySelectorAll(`[data-download-link="${kind}"]`);
    links.forEach(link => { link.hidden = !url; if (url) link.href = url; });
    if (!url) continue;
    enabled += 1;
    const image = card.querySelector('img');
    const save = document.querySelector(`#save-${kind}-qr`);
    // Never show an old static code if a future configuration changes its URL.
    image.hidden = true;
    save.hidden = true;
    try {
      const matrix = qrMatrix(url), cell = 12, quiet = 4;
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = (matrix.length + quiet * 2) * cell;
      const context = canvas.getContext('2d');
      if (!context) throw new Error('Canvas unavailable');
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.fillStyle = '#182b25';
      matrix.forEach((row, y) => row.forEach((dark, x) => {
        if (dark) context.fillRect((x + quiet) * cell, (y + quiet) * cell, cell, cell);
      }));
      image.src = save.href = canvas.toDataURL('image/png');
      image.hidden = save.hidden = false;
    } catch { /* Direct links still work when canvas is unavailable. */ }
    const copy = document.querySelector(`#copy-${kind}-link`);
    const status = document.querySelector(`#${kind}-copy-status`);
    copy.hidden = false;
    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(url);
        status.textContent = '链接已复制，可以发给朋友了。';
      } catch { status.textContent = '复制未成功，请长按下载按钮复制链接。'; }
    });
  }
  document.querySelector('.testflight-help').hidden = !publicDownloadURL(config.testFlightURL, 'testflight');
  const status = document.querySelector('#release-status');
  status.hidden = enabled > 0;
  status.textContent = enabled ? '' : '下载入口准备中。';
  if (config.testFlightStatus !== 'open') {
    document.querySelector('#testflight-link').textContent = '查看 TestFlight 邀请';
    document.querySelector('#testflight-note').textContent = '公开测试准备中，开放后可通过此邀请加入。';
  }
}
