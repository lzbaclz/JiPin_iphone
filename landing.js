(() => {
  'use strict';
  const menuButton = document.querySelector('.menu-toggle');
  const navigation = document.querySelector('#main-nav');
  if (menuButton && navigation) {
    document.documentElement.classList.add('js');
    menuButton.hidden = false;
    const closeMenu = () => {
      menuButton.setAttribute('aria-expanded', 'false');
      menuButton.querySelector('.sr-only').textContent = '展开导航';
      navigation.classList.remove('is-open');
    };
    menuButton.addEventListener('click', () => {
      const isOpen = menuButton.getAttribute('aria-expanded') !== 'true';
      menuButton.setAttribute('aria-expanded', String(isOpen));
      menuButton.querySelector('.sr-only').textContent = isOpen ? '收起导航' : '展开导航';
      navigation.classList.toggle('is-open', isOpen);
    });
    navigation.addEventListener('click', (event) => {
      if (event.target.closest('a')) closeMenu();
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
        closeMenu();
        menuButton.focus();
      }
    });
    matchMedia('(min-width: 681px)').addEventListener('change', closeMenu);
  }

  const modes = {
    template: {
      label: '模板拼图', number: '01', title: '选好照片，好看就位。',
      description: '从简单的两张，到满满一屏的回忆。选一个模板，轻轻调整，就能拼得整整齐齐。',
      features: ['2–16 张照片，自由组合', '少裁切布局推荐，留下更多画面', '比例、间距与圆角，都能调整']
    },
    freeform: {
      label: '自由拼图', number: '02', title: '不按格子，按心情。',
      description: '把照片错落地叠在一起，像在桌上摊开一叠刚洗好的相片。旋转一点，再添一行心里话。',
      features: ['自由摆放、缩放、旋转照片', '调整图层，叠出手帐的感觉', '搭配文字、贴纸和喜欢的背景']
    },
    poster: {
      label: '海报拼图', number: '03', title: '普通一天，也值得有封面。',
      description: '给旅行做一张纪念海报，给周末留一页生活封面。把喜欢的画面放大，再为它起个名字。',
      features: ['一键套用海报版式', '编辑标题，写下此刻的心情', '照片与装饰一起排出仪式感']
    },
    'long-strip': {
      label: '长图拼接', number: '04', title: '把一段故事，慢慢展开。',
      description: '从出发时的车窗，到最后一杯咖啡。让照片按顺序连起来，往下看，就又走过了一天。',
      features: ['2–20 张照片，按顺序拼接', '横向或纵向，跟着故事走', '支持静态长图分页导出']
    }
  };
  let selectedMode = 'template';
  const tabs = [...document.querySelectorAll('[data-mode]')];
  const modePanel = document.querySelector('#mode-panel');
  const screenshotDialog = document.querySelector('.screenshot-dialog');
  const screenshotImage = document.querySelector('.dialog-image');
  const updateMode = (key) => {
    const mode = modes[key];
    if (!mode) return;
    selectedMode = key;
    tabs.forEach((tab) => {
      const selected = tab.dataset.mode === key;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    modePanel.setAttribute('aria-labelledby', `tab-${key}`);
    document.querySelector('.collage-stage').dataset.layout = key;
    document.querySelector('.demo-collage').setAttribute('aria-label', `四张原创插画的${mode.label}示意`);
    document.querySelector('.mode-number').textContent = mode.number;
    document.querySelector('#mode-title').textContent = mode.title;
    document.querySelector('#mode-description').textContent = mode.description;
    document.querySelector('#mode-features').replaceChildren(...mode.features.map((text) => {
      const item = document.createElement('li');
      item.textContent = text;
      return item;
    }));
  };
  tabs.forEach((tab, index) => {
    tab.disabled = false;
    tab.addEventListener('click', () => updateMode(tab.dataset.mode));
    tab.addEventListener('keydown', (event) => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next === undefined) return;
      event.preventDefault();
      updateMode(tabs[next].dataset.mode);
      tabs[next].focus();
    });
  });

  const screenshotTrigger = document.querySelector('.screenshot-trigger');
  screenshotTrigger.hidden = false;
  screenshotTrigger.addEventListener('click', () => {
    screenshotImage.src = `assets/screens/${selectedMode}.webp`;
    screenshotImage.alt = `${modes[selectedMode].label}的极拼 App 实际界面`;
    document.querySelector('#screenshot-title').textContent = `${modes[selectedMode].label} · App 实际界面`;
    screenshotDialog.showModal();
    document.body.style.overflow = 'hidden';
    screenshotDialog.scrollTop = 0;
  });
  document.querySelector('.dialog-close').addEventListener('click', () => screenshotDialog.close());
  screenshotDialog.addEventListener('click', (event) => {
    if (event.target !== screenshotDialog) return;
    const bounds = screenshotDialog.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) screenshotDialog.close();
  });
  screenshotDialog.addEventListener('close', () => {
    document.body.style.overflow = '';
    screenshotTrigger.focus({ preventScroll: true });
  });

  const video = document.querySelector('#live-video');
  const liveToggle = document.querySelector('.live-toggle');
  if (video && liveToggle) {
    liveToggle.hidden = false;
    const refreshVideoButton = () => {
      liveToggle.querySelector('.toggle-icon').textContent = video.paused ? '▶' : 'Ⅱ';
      liveToggle.querySelector('.toggle-text').textContent = video.paused ? '播放 Live 演示' : '暂停 Live 演示';
    };
    video.addEventListener('play', refreshVideoButton);
    video.addEventListener('pause', refreshVideoButton);
    video.addEventListener('error', () => {
      liveToggle.querySelector('.toggle-text').textContent = '演示暂不可用，请稍后重试';
      liveToggle.disabled = true;
    });
    liveToggle.addEventListener('click', async () => {
      if (!video.paused) { video.pause(); return; }
      try { await video.play(); }
      catch { liveToggle.querySelector('.toggle-text').textContent = '请点击视频内的播放按钮'; }
    });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((entries) => {
        if (!entries[0].isIntersecting) video.pause();
      }, { rootMargin: '120px' }).observe(document.querySelector('#live'));
    }
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) video.pause();
    });
  }

  const workspace = document.querySelector('#sticker-workspace');
  const placed = document.querySelector('.placed-stickers');
  const stickerStatus = document.querySelector('#sticker-status');
  const removeSticker = document.querySelector('#remove-sticker');
  const trayButtons = [...document.querySelectorAll('[data-sticker]')];
  const names = { 'cute-bunny': '小兔', 'cute-bow': '蝴蝶结', 'cute-daisy': '小花', 'cute-cherries': '樱桃', 'cool-bolt': '闪电', 'cool-orbit': '星球' };
  const maxStickers = 8;
  let selectedSticker = null;
  let sequence = 0;
  let drag = null;
  let dragFrame = 0;
  const setSelection = (element) => {
    placed.querySelectorAll('button').forEach((item) => item.setAttribute('aria-pressed', String(item === element)));
    selectedSticker = element;
    removeSticker.disabled = !element;
    if (element) {
      placed.querySelectorAll('button').forEach((item, index) => { item.style.zIndex = String(index + 1); });
      element.style.zIndex = String(maxStickers + 1);
    }
  };
  const refreshStickerState = (message) => {
    const count = placed.childElementCount;
    trayButtons.forEach((button) => { button.disabled = count >= maxStickers; });
    stickerStatus.textContent = message || (count >= maxStickers ? '已放满 8 张，可移除或重新开始' : `${count} / ${maxStickers} 张贴纸 · 拖动试试看`);
  };
  const positionSticker = (element, x, y, bounds) => {
    const rect = bounds || workspace.getBoundingClientRect();
    const marginX = 14;
    const marginY = Math.min(20, marginX * rect.width / rect.height);
    const nextX = Math.max(marginX, Math.min(100 - marginX, x));
    const nextY = Math.max(marginY, Math.min(100 - marginY, y));
    element.dataset.x = String(nextX);
    element.dataset.y = String(nextY);
    element.style.setProperty('--x', `${nextX}%`);
    element.style.setProperty('--y', `${nextY}%`);
  };
  const renderDrag = () => {
    dragFrame = 0;
    if (!drag) return;
    positionSticker(drag.element, drag.x, drag.y, drag.bounds);
  };
  const finishDrag = () => {
    if (!drag) return;
    if (dragFrame) cancelAnimationFrame(dragFrame);
    renderDrag();
    const element = drag.element;
    element.classList.remove('dragging');
    const id = drag.pointerId;
    drag = null;
    if (element.hasPointerCapture(id)) element.releasePointerCapture(id);
    refreshStickerState();
  };
  const deleteSelectedSticker = () => {
    finishDrag();
    if (!selectedSticker) return;
    selectedSticker.remove();
    setSelection(null);
    refreshStickerState();
  };
  const addSticker = (key, x = 35 + (sequence * 17) % 38, y = 30 + (sequence * 13) % 38, announce = true) => {
    if (!names[key] || placed.childElementCount >= maxStickers) return;
    sequence += 1;
    const element = document.createElement('button');
    element.type = 'button';
    element.className = 'placed-sticker';
    element.setAttribute('aria-label', `${names[key]}贴纸 ${sequence}，可拖动或用方向键移动`);
    element.setAttribute('aria-pressed', 'false');
    element.style.setProperty('--angle', `${(sequence % 5 - 2) * 6}deg`);
    const stickerImage = document.createElement('img');
    stickerImage.src = `assets/stickers/${key}.webp`;
    stickerImage.alt = '';
    stickerImage.width = 240;
    stickerImage.height = 240;
    stickerImage.draggable = false;
    element.append(stickerImage);
    placed.append(element);
    positionSticker(element, x, y);
    if (announce) setSelection(element);
    element.addEventListener('focus', () => setSelection(element));
    element.addEventListener('pointerdown', (event) => {
      if (!event.isPrimary || event.button !== 0) return;
      finishDrag();
      setSelection(element);
      element.focus({ preventScroll: true });
      element.setPointerCapture(event.pointerId);
      const bounds = workspace.getBoundingClientRect();
      drag = { element, bounds, pointerId: event.pointerId, startX: event.clientX, startY: event.clientY,
        initialX: Number(element.dataset.x), initialY: Number(element.dataset.y), x: Number(element.dataset.x), y: Number(element.dataset.y) };
      element.classList.add('dragging');
    });
    element.addEventListener('pointermove', (event) => {
      if (!drag || drag.element !== element || event.pointerId !== drag.pointerId) return;
      drag.x = drag.initialX + (event.clientX - drag.startX) / drag.bounds.width * 100;
      drag.y = drag.initialY + (event.clientY - drag.startY) / drag.bounds.height * 100;
      if (!dragFrame) dragFrame = requestAnimationFrame(renderDrag);
    });
    for (const eventName of ['pointerup', 'pointercancel', 'lostpointercapture']) {
      element.addEventListener(eventName, (event) => {
        if (drag?.element === element && drag.pointerId === event.pointerId) finishDrag();
      });
    }
    element.addEventListener('keydown', (event) => {
      const directions = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
      if (directions[event.key]) {
        event.preventDefault();
        const [dx, dy] = directions[event.key];
        const step = event.shiftKey ? 5 : 1;
        positionSticker(element, Number(element.dataset.x) + dx * step, Number(element.dataset.y) + dy * step);
      } else if (event.key === 'Delete' || event.key === 'Backspace') {
        event.preventDefault();
        deleteSelectedSticker();
        trayButtons[0].focus();
      }
    });
    refreshStickerState();
    return element;
  };
  const resetStickers = () => {
    finishDrag();
    placed.replaceChildren();
    sequence = 0;
    setSelection(null);
    addSticker('cute-bunny', 22, 69, false);
    addSticker('cute-daisy', 80, 25, false);
    refreshStickerState();
  };
  trayButtons.forEach((button) => button.addEventListener('click', () => addSticker(button.dataset.sticker)));
  removeSticker.addEventListener('click', deleteSelectedSticker);
  document.querySelector('#reset-stickers').disabled = false;
  document.querySelector('#reset-stickers').addEventListener('click', resetStickers);
  resetStickers();

  // Format checks do not replace verifying that a public release actually exists.
  const publicURL = (value, host, pathPattern) => {
    if (typeof value !== 'string' || !value.trim()) return null;
    try {
      const url = new URL(value);
      return url.protocol === 'https:' && url.hostname === host && !url.username && !url.password && pathPattern.test(url.pathname) ? url.href : null;
    } catch { return null; }
  };
  const config = window.JIPIN_SITE || {};
  const appStoreURL = publicURL(config.appStoreURL, 'apps.apple.com', /^\/(?:[a-z]{2}\/)?app\//);
  const testFlightURL = publicURL(config.testFlightURL, 'testflight.apple.com', /^\/join\/[a-zA-Z0-9]+\/?$/);
  if (appStoreURL || testFlightURL) {
    document.querySelector('#release-status').hidden = true;
    document.querySelector('#download-note').textContent = testFlightURL && !appStoreURL ? '通过 TestFlight 体验内测版 · 适用于 iPhone · iOS 17 或更新版本' : '适用于 iPhone · iOS 17 或更新版本';
    [[appStoreURL, '#app-store-link'], [testFlightURL, '#testflight-link']].forEach(([url, selector]) => {
      if (!url) return;
      const link = document.querySelector(selector);
      link.href = url;
      link.hidden = false;
    });
  }
  if (testFlightURL) {
    // An invitation still works if QR rendering cannot load.
    import('./testflight-invite.mjs?v=135dd9b171').then(({ mountTestFlightInvitation }) => {
      mountTestFlightInvitation(testFlightURL);
    }).catch(() => {});
  }
})();
