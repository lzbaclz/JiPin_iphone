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
    matchMedia('(min-width: 760px)').addEventListener('change', closeMenu);
  }

  const modes = {
    template: {
      label: '模板拼图', number: '01', title: '选好照片，好看就位。',
      description: '从两张照片开始，选择合适的模板，调整画面的位置与留白。',
      features: ['2–16 张照片，自由组合', '少裁切布局推荐，留下更多画面', '比例、间距与圆角，都能调整']
    },
    freeform: {
      label: '自由拼图', number: '02', title: '不按格子，按心情。',
      description: '照片的位置、大小和方向由你决定，叠放出自己的旅行手帐。',
      features: ['自由摆放、缩放、旋转照片', '调整图层，叠出手帐的感觉', '搭配文字、贴纸和喜欢的背景']
    },
    poster: {
      label: '海报拼图', number: '03', title: '普通一天，也值得有封面。',
      description: '让一张照片成为主角，配上标题与留白，为一段旅程做个封面。',
      features: ['一键套用海报版式', '编辑标题，写下此刻的心情', '照片与装饰一起排出仪式感']
    },
    'long-strip': {
      label: '长图拼接', number: '04', title: '把一段故事，慢慢展开。',
      description: '把照片按顺序横向或纵向连接，保留沿途的完整画面。',
      features: ['2–20 张照片，按顺序拼接', '横向或纵向，跟着故事走', '支持静态长图分页导出']
    }
  };
  const playbackRefresh = new Map();
  let selectedMode = 'template';
  let selectedTheme = 'cute';
  const exampleThemes = [...document.querySelectorAll('[data-example-theme]')];
  const viewport = document.querySelector('#mode-viewport');
  const resultImage = document.querySelector('#mode-result');
  const modeVideo = document.querySelector('#mode-video');
  const stripPosition = document.querySelector('#long-strip-position');
  const stripProgress = document.querySelector('#long-strip-progress');
  const stripControls = ['#long-strip-controls', '#long-strip-progress', '#long-strip-next', '#long-strip-top'].map(selector => document.querySelector(selector));
  const syncStripPosition = () => {
    const max = Math.max(viewport.scrollHeight - viewport.clientHeight, 0);
    const percent = max ? Math.round(viewport.scrollTop / max * 100) : 0;
    stripPosition.disabled = !max;
    stripPosition.value = String(percent);
    stripPosition.setAttribute('aria-valuetext', `已浏览 ${percent}%`);
    stripProgress.textContent = `已浏览 ${percent}%`;
    document.querySelector('#long-strip-top').disabled = percent === 0;
    document.querySelector('#long-strip-next').disabled = percent === 100;
  };
  viewport.addEventListener('scroll', syncStripPosition, { passive: true });
  stripPosition.addEventListener('input', () => {
    viewport.scrollTop = (viewport.scrollHeight - viewport.clientHeight) * Number(stripPosition.value) / 100;
    syncStripPosition();
  });
  const scrollBehavior = () => matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth';
  document.querySelector('#long-strip-next').addEventListener('click', () => viewport.scrollBy({ top: viewport.clientHeight * 0.85, behavior: scrollBehavior() }));
  document.querySelector('#long-strip-top').addEventListener('click', () => viewport.scrollTo({ top: 0, behavior: scrollBehavior() }));
  resultImage.addEventListener('load', () => {
    modeVideo.width = resultImage.naturalWidth;
    modeVideo.height = resultImage.naturalHeight;
    syncStripPosition();
  });
  modeVideo.addEventListener('loadedmetadata', syncStripPosition);
  if ('ResizeObserver' in window) new ResizeObserver(syncStripPosition).observe(viewport);
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
    const base = `assets/examples/${selectedTheme}-${key}`;
    const themeName = selectedTheme === 'cute' ? '可爱日常' : '山河旅行';
    modeVideo.pause();
    modeVideo.hidden = true;
    resultImage.hidden = false;
    resultImage.src = `${base}.webp`;
    resultImage.alt = `即拼用${themeName}素材生成的${mode.label}成品`;
    resultImage.removeAttribute('width');
    resultImage.removeAttribute('height');
    modeVideo.src = `${base}.mp4`;
    modeVideo.poster = `${base}.webp`;
    modeVideo.setAttribute('aria-label', `${themeName}${mode.label}的动态成品预览`);
    modeVideo.load();
    playbackRefresh.get(modeVideo)?.();
    document.querySelector('#mode-caption').textContent = `${themeName} · 即拼实际合成`;
    viewport.setAttribute('aria-label', key === 'long-strip' ? '长图预览，可滚动或拖动旁边滑块' : '拼图预览');
    stripControls.forEach(control => { control.hidden = key !== 'long-strip'; });
    exampleThemes.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.exampleTheme === selectedTheme)));
    viewport.scrollTop = 0;
    requestAnimationFrame(syncStripPosition);
    document.querySelector('.mode-number').textContent = mode.number;
    document.querySelector('#mode-title').textContent = mode.title;
    document.querySelector('#mode-description').textContent = mode.description;
    document.querySelector('#mode-features').replaceChildren(...mode.features.map((text) => {
      const item = document.createElement('li');
      item.textContent = text;
      return item;
    }));
  };
  exampleThemes.forEach(button => button.addEventListener('click', () => {
    selectedTheme = button.dataset.exampleTheme;
    updateMode(selectedMode);
  }));
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
    screenshotImage.alt = `${modes[selectedMode].label}的即拼 App 实际界面`;
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

  const videos = [...document.querySelectorAll('video')];
  for (const button of document.querySelectorAll('[data-play]')) {
    const video = document.getElementById(button.dataset.play);
    if (!video) continue;
    video.controls = false;
    button.hidden = false;
    const label = button.dataset.label;
    const refresh = () => {
      const active = !video.paused;
      button.setAttribute('aria-pressed', String(active));
      button.setAttribute('aria-label', active ? label.replace('播放', '暂停') : label);
      const icon = button.querySelector('.play-symbol') || button.querySelector('span');
      if (icon) icon.textContent = active ? 'Ⅱ' : '▶';
      const text = button.querySelector('.play-label');
      if (text) text.textContent = active ? label.replace('播放', '暂停') : label;
    };
    video.addEventListener('play', refresh);
    video.addEventListener('pause', refresh);
    video.addEventListener('ended', refresh);
    video.addEventListener('emptied', refresh);
    video.addEventListener('loadstart', refresh);
    playbackRefresh.set(video, refresh);
    button.addEventListener('click', async () => {
      if (!video.paused) { video.pause(); return; }
      videos.forEach(other => { if (other !== video) other.pause(); });
      const requestedSource = video.src || video.currentSrc;
      try {
        if (video === modeVideo) {
          const offset = viewport.scrollTop;
          video.width = resultImage.naturalWidth || video.width;
          video.height = resultImage.naturalHeight || video.height;
          video.hidden = false;
          resultImage.hidden = true;
          viewport.scrollTop = offset;
          viewport.scrollIntoView({ block: 'nearest', behavior: 'instant' });
          requestAnimationFrame(syncStripPosition);
        }
        if (video.error) video.load();
        await video.play();
        if ((video.src || video.currentSrc) !== requestedSource) return;
        if (document.hidden) video.pause();
        button.removeAttribute('title');
      } catch (error) {
        if (error.name === 'AbortError' || (video.src || video.currentSrc) !== requestedSource) { refresh(); return; }
        video.controls = true;
        button.setAttribute('aria-label', '播放失败，点击重试');
        const text = button.querySelector('.play-label');
        if (text) text.textContent = '播放失败，点此重试';
        button.title = '播放失败，请重试或使用视频控件';
      }
    });
  }
  if ('IntersectionObserver' in window) {
    // A long video is taller than its preview. Observe the visible viewport,
    // otherwise scrolling within a long collage can incorrectly pause playback.
    const observedVideos = new Map(videos.map(video => [video === modeVideo ? viewport : video, video]));
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => { if (!entry.isIntersecting) observedVideos.get(entry.target)?.pause(); });
    }, { threshold: 0.1 });
    observedVideos.forEach((video, target) => observer.observe(target));
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) videos.forEach(video => video.pause());
  });

  updateMode(selectedMode);

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
    addSticker('cute-daisy', 82, 73, false);
    refreshStickerState();
  };
  trayButtons.forEach((button) => button.addEventListener('click', () => addSticker(button.dataset.sticker)));
  removeSticker.addEventListener('click', deleteSelectedSticker);
  document.querySelector('#reset-stickers').disabled = false;
  document.querySelector('#reset-stickers').addEventListener('click', resetStickers);
  resetStickers();

  const filters = [...document.querySelectorAll('[data-sticker-filter]')];
  const selectStickerCategory = (category) => {
    filters.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.stickerFilter === category)));
    trayButtons.forEach(button => { button.hidden = button.dataset.category !== category; });
  };
  filters.forEach(button => button.addEventListener('click', () => selectStickerCategory(button.dataset.stickerFilter)));
  selectStickerCategory('cute');

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
  const pendingReview = Boolean(testFlightURL && config.testFlightStatus !== 'open');
  const invitation = document.querySelector('#testflight-invitation');
  const status = document.querySelector('#release-status');
  invitation.hidden = !testFlightURL;
  status.hidden = Boolean((appStoreURL || testFlightURL) && !pendingReview);
  if (pendingReview) {
    status.textContent = 'TestFlight 外测审核中';
    document.querySelector('#testflight-link').textContent = '查看 TestFlight 邀请';
    document.querySelector('.install-steps').hidden = true;
  }
  document.querySelector('#download-note').textContent = pendingReview
    ? 'Apple 审核通过后，可通过同一个邀请链接加入。'
    : testFlightURL ? '公开内测 · 无需邀请码' : '下载入口准备中，开放后在这里更新。';
  [[appStoreURL, '#app-store-link'], [testFlightURL, '#testflight-link']].forEach(([url, selector]) => {
    if (!url) return;
    const link = document.querySelector(selector);
    link.href = url;
    link.hidden = false;
  });
  const phoneWidth = matchMedia('(max-width: 759px)');
  const adaptInvitation = () => { invitation.open = !phoneWidth.matches; };
  adaptInvitation();
  phoneWidth.addEventListener('change', adaptInvitation);
  invitation.addEventListener('toggle', () => {
    if (!phoneWidth.matches && !invitation.open) invitation.open = true;
  });
  if (testFlightURL) {
    import('./testflight-invite.mjs?v=6d560a0f76').then(({ mountTestFlightInvitation }) => {
      mountTestFlightInvitation(testFlightURL, { pendingReview });
    }).catch(() => { invitation.hidden = true; });
  }
})();
