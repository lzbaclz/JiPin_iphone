import qrcode from './assets/vendor/qrcode-generator/qrcode.mjs?v=2.0.4';

// Both the QR image and every invitation button use this same canonical URL.
export function publicInviteURL(value) {
  try {
    const url = new URL(value);
    if (url.origin !== 'https://testflight.apple.com' || url.username || url.password || !/^\/join\/[a-zA-Z0-9]+\/?$/.test(url.pathname)) return null;
    return `${url.origin}${url.pathname.replace(/\/$/, '')}`;
  } catch { return null; }
}

export function mountTestFlightInvitation(value) {
  const url = publicInviteURL(value);
  if (!url) return false;
  const heroCard = document.querySelector('#hero-testflight');
  const invitation = document.querySelector('#testflight-invitation');
  if (!heroCard || !invitation) return false;

  const qr = qrcode(0, 'M');
  qr.addData(url, 'Byte');
  qr.make();

  // A four-module white quiet zone, whole pixels, and no logo over the code.
  const quietZone = 4;
  const cellSize = 12;
  const count = qr.getModuleCount();
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = (count + quietZone * 2) * cellSize;
  const context = canvas.getContext('2d');
  if (!context) return false;
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = '#24282c';
  for (let row = 0; row < count; row += 1) {
    for (let column = 0; column < count; column += 1) {
      if (qr.isDark(row, column)) context.fillRect((column + quietZone) * cellSize, (row + quietZone) * cellSize, cellSize, cellSize);
    }
  }
  const imageURL = canvas.toDataURL('image/png');
  for (const image of document.querySelectorAll('[data-testflight-qr]')) image.src = imageURL;
  heroCard.href = url;
  const address = document.querySelector('#testflight-address');
  address.href = url;
  address.textContent = url;
  const download = document.querySelector('#save-testflight-qr');
  download.href = imageURL;
  download.download = 'jipin-testflight.png';
  const directLink = document.querySelector('#testflight-link');
  directLink.href = url;

  const copyButton = document.querySelector('#copy-testflight-link');
  const status = document.querySelector('#testflight-copy-status');
  copyButton.addEventListener('click', async () => {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(url);
      status.textContent = '邀请链接已复制，可以发给朋友了。';
    } catch {
      status.textContent = '请长按或选中上方邀请链接，手动复制。';
    }
  });

  document.querySelector('.hero-art').classList.add('has-testflight');
  heroCard.hidden = false;
  invitation.hidden = false;
  return true;
}
