import qrcode from './assets/vendor/qrcode-generator/qrcode.mjs?v=2.0.4';

export function publicInviteURL(value) {
  try {
    const url = new URL(value);
    if (url.origin !== 'https://testflight.apple.com' || url.username || url.password || !/^\/join\/[a-zA-Z0-9]+\/?$/.test(url.pathname)) return null;
    return `${url.origin}${url.pathname.replace(/\/$/, '')}`;
  } catch { return null; }
}

export function mountTestFlightInvitation(value, { pendingReview = true } = {}) {
  const url = publicInviteURL(value);
  const invitation = document.querySelector('#testflight-invitation');
  if (!url || !invitation) return false;
  const qr = qrcode(0, 'M');
  qr.addData(url, 'Byte');
  qr.make();
  const quietZone = 4, cellSize = 12, count = qr.getModuleCount();
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = (count + quietZone * 2) * cellSize;
  const context = canvas.getContext('2d');
  if (!context) return false;
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = '#182b25';
  for (let row = 0; row < count; row += 1) {
    for (let column = 0; column < count; column += 1) {
      if (qr.isDark(row, column)) context.fillRect((column + quietZone) * cellSize, (row + quietZone) * cellSize, cellSize, cellSize);
    }
  }
  const imageURL = canvas.toDataURL('image/png');
  document.querySelectorAll('[data-testflight-qr]').forEach(image => { image.src = imageURL; });
  const address = document.querySelector('#testflight-address');
  address.href = url;
  address.textContent = url.replace('https://', '');
  const save = document.querySelector('#save-testflight-qr');
  save.href = imageURL;
  save.download = 'jipin-testflight.png';
  document.querySelector('#testflight-link').href = url;
  if (pendingReview) {
    document.querySelector('#testflight-title').textContent = '邀请已准备好，Apple 审核通过后可加入。';
    document.querySelector('.desktop-share-title').textContent = '扫码查看内测邀请';
  }
  const copy = document.querySelector('#copy-testflight-link');
  const status = document.querySelector('#testflight-copy-status');
  copy.hidden = false;
  copy.addEventListener('click', async () => {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(url);
      status.textContent = pendingReview ? '邀请已复制，审核通过后可加入。' : '邀请已复制，可以发给朋友了。';
    } catch { status.textContent = '请长按上方邀请链接，手动复制。'; }
  });
  invitation.hidden = false;
  return true;
}
