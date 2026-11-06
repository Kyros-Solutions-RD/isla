/* Isla website: language, the menu bar island, live desktop demo, comparisons and motion. */
(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const canHover = window.matchMedia('(hover: hover)').matches;

  /* ---------------- Language ---------------- */

  const en = {
    'skip': 'Skip to content',
    'nav.badge': 'Free', 'nav.try': 'Try it', 'nav.features': 'Features', 'nav.free': 'Price', 'nav.news': 'What’s new', 'nav.faq': 'FAQ', 'nav.download': 'Download',
    'island.label': 'What’s new',
    'hero.news': 'What’s new in version',
    'hero.title1': 'Your notch, now', 'hero.title2': 'an island.',
    'hero.sub': 'Music with lyrics, a Shelf with AirDrop, calendar, teleprompter, terminal and more: over 40 features under your camera. Free and open source.',
    'hero.cta': 'Download Isla', 'hero.try': 'Try it here',
    'hero.meta': 'Free forever · macOS 26 Tahoe or later · also on Macs without a notch',
    'demo.title': 'Try it before you download it', 'demo.sign': 'TRY IT',
    'demo.openAria': 'Open the Nook', 'demo.hint': 'try dragging a file to the notch',
    'demo.after': 'Like it? Download it free: no account, no trial and no limits.', 'demo.news': 'See what’s new →',
    'mb.file': 'File', 'mb.edit': 'Edit',
    'tab.home': 'Nook', 'tab.shelf': 'Shelf', 'tab.clipboard': 'Clipboard', 'tab.calendar': 'Calendar', 'tab.tasks': 'Tasks',
    'tab.timers': 'Focus', 'tab.notes': 'Notes', 'tab.teleprompter': 'Teleprompter', 'tab.terminal': 'Terminal', 'tab.actions': 'Actions',
    'tab.agents': 'AI', 'act.agents': 'An agent at work',
    'b.agents.t': 'Your AI agents, in sight', 'b.agents.p': 'Codex, Gemini CLI, Antigravity and the other agents working on your Mac: which folder, since when, what they are doing now and whether they need you. Plus the models Ollama and LM Studio keep in memory. No permissions, and nothing leaves your Mac.',
    'style.classic': 'Classic',
    'act.airpods': 'Connect AirPods', 'act.charging': 'Plug in the charger', 'act.volume': 'Turn up the volume', 'act.brightness': 'Dim the screen',
    'act.meeting': 'Meeting in 4 min', 'act.download': 'Download a file', 'act.track': 'Change the song', 'act.lyrics': 'Lyrics under the island',
    'act.timer': 'Pomodoro done', 'act.caps': 'Caps Lock',
    'live.title': 'The island keeps you posted.',
    'live.lead': 'Charging, AirPods with their battery, volume and brightness, downloads, meetings, timers, your AI agents and your song. They appear around the notch and leave on their own; when two happen at once, the second waits in a bubble.',
    'features.title1': 'More than 40 features.', 'features.title2': 'Zero cost.',
    'features.lead': 'Everything you’d expect from the best notch app, and a few things you wouldn’t.',
    'b.music.t': 'Music you can see', 'b.music.p': 'Any app in Now Playing: Music, Spotify, Podcasts or your browser. Artwork, controls, synced lyrics and glass that takes on the album’s color.',
    'b.shelf.t': 'Drop. Keep. Send.', 'b.shelf.p': 'Drag onto the notch and files wait on the Shelf. AirDrop, share and convert to PNG, JPEG, HEIC, PDF, MP4 or ZIP. Far from the notch? Shake the pointer and a Pocket appears.',
    'b.clip.t': 'Everything you copied', 'b.clip.p': 'History with search, filters and pins. Never stores passwords.',
    'b.cal.t': 'Your week at a glance', 'b.cal.p': 'iCloud, Google and Exchange, with a button to join Zoom, Meet or Teams.',
    'b.term.t': 'A real terminal', 'b.term.p': 'Your shell under the notch. It keeps running even when you close the panel.',
    'b.focus.t': 'Focus', 'b.focus.p': 'Pomodoro, timers, a stopwatch and brown noise generated on your Mac.',
    'b.prompt.t': 'Talk to camera without losing your place', 'b.prompt.p': 'A teleprompter right under the lens that scrolls at your pace or follows your voice, recognized on your Mac.',
    'b.actions.t': 'Quick Actions', 'b.actions.p': 'Keep your Mac awake, pick a color, capture to the Shelf, lock the screen or switch to dark mode.',
    'm.tasks.t': 'Tasks', 'm.tasks.p': 'Synced with Reminders.', 'm.notes.t': 'Notes', 'm.notes.p': 'Quick, local, exportable to Notes.',
    'm.mirror.t': 'Mirror', 'm.mirror.p': 'Check yourself before a call.', 'm.shortcuts.t': 'Shortcuts', 'm.shortcuts.p': 'Run your macOS Shortcuts.',
    'm.weather.t': 'Weather', 'm.weather.p': 'Now and the next hours, with highs and lows.', 'm.hud.t': 'Volume HUD', 'm.hud.p': 'Replaces the system overlay.',
    'm.gestures.t': 'Gestures', 'm.gestures.p': 'Swipe to open or change songs.', 'm.screens.t': 'Every display', 'm.screens.p': 'Notched, notchless and external monitors.',
    'm.keys.t': 'Keyboard', 'm.keys.p': '⌃⌥Space opens the island from any app.', 'm.lang.t': 'English and Spanish', 'm.lang.p': 'Fully translated.',
    'm.privacy.t': 'Private', 'm.privacy.p': 'No accounts, no analytics.', 'm.updates.t': 'Always up to date', 'm.updates.p': 'Lets you know when a new version ships.',
    'made.title': 'Truly native. Truly open.',
    'made.quote': '“We made it for our own Macs, on an island in the Caribbean. That’s why it’s called Isla.”',
    'stats.features': 'features under the notch', 'stats.size': 'download, all native', 'stats.trackers': 'accounts, ads or trackers', 'stats.license': 'open source on GitHub',
    'native.title': 'Made the way Apple would.',
    'native.lead': 'Swift and SwiftUI, the system Liquid Glass, SF Symbols, haptics and a Settings window that feels like System Settings. No Electron, no web views.',
    'compare.title': 'Glass or black. Your call.',
    'compare.lead': 'macOS Liquid Glass lets your wallpaper shine through the island. Classic black melts it into the camera. Slide to compare.',
    'free.title': 'One app for the notch. Zero dollars.',
    'free.lead': 'No Pro tier, no 48-hour trial, no subscription and no limit on Macs. Download it ready to go, or build it yourself.',
    'free.compare': 'What’s included? Compare ↓',
    'plan.flag': 'RECOMMENDED', 'plan.a.kicker': 'Ready to use',
    'plan.a.text': 'Download the .dmg, drag it to Applications and you’re done. It updates itself, signed and verified.',
    'plan.a.note': 'free, forever', 'plan.a.chip': 'On every Mac you own', 'plan.a.cta': 'Download Isla',
    'plan.a.foot': 'Version <span data-latest></span> · see what’s new ↗',
    'plan.b.kicker': 'To build it yourself',
    'plan.b.text': 'The same code, on GitHub under the MIT License. Read it, change it or make your own version.',
    'plan.b.note': 'open source', 'plan.b.chip': 'Xcode 26 and XcodeGen', 'plan.b.cta': 'View on GitHub', 'plan.b.foot': 'How to contribute ↗',
    'free.l1': 'Liquid Glass or classic black', 'free.l2': 'Music with synced lyrics', 'free.l3': 'Shelf, AirDrop and Pocket',
    'free.l5': 'Clipboard history', 'free.l6': 'Calendar, tasks and notes', 'free.l8': 'A teleprompter that follows your voice',
    'free.l9': 'A terminal inside the notch', 'free.l12': 'Every update',
    'promise.1.t': 'No account', 'promise.1.p': 'No email, sign-up or card. You download it and use it.',
    'promise.2.t': 'No tracking', 'promise.2.p': 'Zero analytics. Only the weather, lyrics and update check leave your Mac.',
    'promise.3.t': 'Updates itself', 'promise.3.p': 'Every version arrives signed and lets you know on the island. <a href="novedades/">What’s new</a>.',
    'cmp.title': 'What changes with Isla?', 'cmp.feature': 'Feature', 'cmp.base': 'The plain notch', 'cmp.isla': 'With Isla',
    'cmp.r1': 'Music with synced lyrics under the notch', 'cmp.r2': 'A file Shelf with AirDrop and conversions', 'cmp.r3': 'Calendar with a button to join meetings',
    'cmp.r4': 'Clipboard history', 'cmp.r5': 'Teleprompter and terminal under the camera', 'cmp.r6': 'Live activities: AirPods, charging, downloads',
    'cmp.r7': 'A redesigned volume and brightness overlay', 'cmp.r8': 'An island on Macs and displays without a notch',
    'cmp.note': 'Isla needs macOS 26 Tahoe or later, on a Mac with Apple silicon or Intel.',
    'open.cta': 'View on GitHub', 'code.c1': 'Build Isla in a minute',
    'final.title': 'Ready to bring your notch to life?',
    'final.lead': 'More than 40 features around the notch: music, files, calendar, teleprompter and much more. Free, no account and open source.',
    'faq.title': 'Questions, answered.', 'faq.lead': 'The short version of what people ask us most.',
    'faq.q1': 'Is Isla really free?', 'faq.a1': 'Yes. Every feature is free, forever, with no trial and no subscription. The code is on GitHub under the MIT License.',
    'faq.q2': 'Which Mac do I need?', 'faq.a2': 'Any Mac running macOS 26 Tahoe or later, with Apple silicon or Intel. Isla uses the system Liquid Glass, which is why it requires Tahoe.',
    'faq.q3': 'What if my Mac has no notch?', 'faq.a3': 'Isla draws a matching island at the top of any display, external monitors included. You choose which displays show it.',
    'faq.q4': 'Which music apps does it work with?', 'faq.a4': 'Any app that shows up in Control Center’s Now Playing: Music, Spotify, Podcasts, YouTube in the browser and more. Lyrics come from LRCLIB, an open database.',
    'faq.q5': 'What permissions does it ask for, and what happens to my data?', 'faq.a5': 'Only the ones you turn on: Calendar, Reminders, Camera for the Mirror, Location for weather, Microphone for the teleprompter and Accessibility for the volume overlay. Nothing leaves your Mac except the weather lookup with an approximate location, the lyrics search and the update check.',
    'faq.q6': 'macOS says it can’t verify the app. What do I do?', 'faq.a6': 'Community builds are signed without a paid Apple certificate. Open System Settings › Privacy & Security, scroll down, click “Open Anyway” and confirm. You only do this once. Or build it yourself from source.',
    'faq.q7': 'How do I hear about new versions?', 'faq.a7': 'Isla checks for updates once a day and tells you right on the island; they install in one click. Everything that changes is in <a href="novedades/">What’s new</a>. You can turn the check off in Settings.',
    'faq.more': 'Still have a question? Write to us on',
    'footer.tag': 'Your notch, now an island. Made with love, and plenty of coffee, in Santo Domingo.',
    'footer.product': 'Product', 'footer.help': 'Help', 'footer.community': 'Community', 'footer.resources': 'Resources',
    'footer.releases': 'Releases', 'footer.changelog': 'What’s new', 'footer.issues': 'Report an issue', 'footer.contribute': 'Contribute ↗', 'footer.rss': 'RSS feed',
    'footer.license': 'MIT License', 'footer.tm': 'Mac, macOS, AirPods and AirDrop are trademarks of Apple Inc. Isla is not affiliated with Apple.',
    'footer.photos': 'Photo behind the captures:',
    'log.title': 'What’s new',
    'log.lead': 'Everything that changes in Isla, version by version. The app updates itself and lets you know on the island; here you can see what each version brings.',
    'log.cta': 'Download Isla', 'log.feed': 'Subscribe via RSS', 'log.list': 'Every version',
    'log.foot': 'Looking for something more technical? Every version is also on',
  };

  const latestVersion = document.querySelector('[data-latest]')?.textContent.trim() || '';
  const nodes = [...document.querySelectorAll('[data-i18n]')];
  const original = new Map(nodes.map((node) => [node, node.textContent]));
  const ariaNodes = [...document.querySelectorAll('[data-i18n-aria]')];
  const originalAria = new Map(ariaNodes.map((node) => [node, node.getAttribute('aria-label')]));
  const toggle = document.querySelector('[data-lang-toggle]');
  let lang = new URLSearchParams(location.search).get('lang') || localStorage.getItem('isla-lang') || 'es';
  if (lang !== 'en') lang = 'es';

  const rich = new Set(nodes.filter((node) => node.children.length > 0 && !node.querySelector('[data-i18n]')));
  rich.forEach((node) => original.set(node, node.innerHTML));

  function applyLanguage() {
    document.documentElement.lang = lang;
    nodes.forEach((node) => {
      const value = lang === 'en' && en[node.dataset.i18n] ? en[node.dataset.i18n] : original.get(node);
      if (rich.has(node)) { node.innerHTML = value; } else { node.textContent = value; }
    });
    ariaNodes.forEach((node) => node.setAttribute('aria-label', lang === 'en' && en[node.dataset.i18nAria] ? en[node.dataset.i18nAria] : originalAria.get(node)));
    if (toggle) {
      toggle.textContent = lang === 'en' ? 'ES' : 'EN';
      toggle.setAttribute('aria-label', lang === 'en' ? 'Cambiar a español' : 'Change language to English');
    }
    document.querySelectorAll('[data-latest]').forEach((node) => { node.textContent = latestVersion; });
    const titles = document.documentElement.dataset;
    document.title = lang === 'en' ? (titles.titleEn || document.title) : (titles.titleEs || document.title);
    updateClock();
    updateBarClock();
    document.dispatchEvent(new CustomEvent('isla:lang', { detail: lang }));
  }

  toggle?.addEventListener('click', () => {
    lang = lang === 'en' ? 'es' : 'en';
    localStorage.setItem('isla-lang', lang);
    // The words cross-fade into the other language instead of jumping.
    if (document.startViewTransition && !reduceMotion) {
      // A transition the browser skips (a hidden tab) still applies the language; only the fade is lost.
      document.startViewTransition(applyLanguage).ready.catch(() => {});
    } else {
      applyLanguage();
    }
  });

  /* ---------------- The notch navigation settles as you scroll ---------------- */

  const notchWrap = document.querySelector('.notchbar-wrap');
  if (notchWrap) {
    let ticking = false;
    const settle = () => { ticking = false; notchWrap.classList.toggle('is-scrolled', window.scrollY > 40); };
    addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(settle); } }, { passive: true });
    settle();
  }

  /* ---------------- Segmented controls: a plate that glides to the choice ---------------- */

  const segs = [...document.querySelectorAll('.seg')];
  function placeThumb(seg, animated = true) {
    const on = seg.querySelector('button.is-on');
    const thumb = seg.querySelector('.seg-thumb');
    if (!on || !thumb) return;
    if (!animated) thumb.style.transition = 'none';
    thumb.style.setProperty('--tx', `${on.offsetLeft}px`);
    thumb.style.setProperty('--ty', `${on.offsetTop}px`);
    thumb.style.setProperty('--tw', `${on.offsetWidth}px`);
    thumb.style.setProperty('--th', `${on.offsetHeight}px`);
    if (!animated) { void thumb.offsetWidth; thumb.style.transition = ''; }
  }
  segs.forEach((seg) => {
    const thumb = document.createElement('span');
    thumb.className = 'seg-thumb';
    thumb.setAttribute('aria-hidden', 'true');
    seg.prepend(thumb);
    seg.classList.add('has-thumb');
    placeThumb(seg, false);
  });
  const placeAll = (animated) => segs.forEach((seg) => placeThumb(seg, animated));
  addEventListener('resize', () => placeAll(false), { passive: true });
  document.addEventListener('isla:lang', () => requestAnimationFrame(() => placeAll(false)));
  document.fonts?.ready.then(() => placeAll(false));

  /* ---------------- Menu bar: clock and island ---------------- */

  const barClock = document.querySelector('[data-bar-clock]');
  function updateBarClock() {
    if (!barClock) return;
    barClock.textContent = new Intl.DateTimeFormat(lang === 'en' ? 'en-US' : 'es-DO', { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date());
  }
  setInterval(updateBarClock, 20000);

  // Like a live activity, the island opens once to announce the latest version, then rests.
  const island = document.querySelector('[data-island]');
  if (island && !reduceMotion) {
    setTimeout(() => island.classList.add('is-open'), 1100);
    setTimeout(() => island.classList.remove('is-open'), 6400);
  }

  /* ---------------- Desktop demo ---------------- */

  const desk = document.querySelector('[data-desk]');
  const clock = document.querySelector('[data-clock]');

  function updateClock() {
    if (!clock) return;
    const now = new Date();
    clock.textContent = new Intl.DateTimeFormat(lang === 'en' ? 'en-US' : 'es-DO', { weekday: 'short', hour: 'numeric', minute: '2-digit' }).format(now);
  }

  if (desk) {
    const panel = desk.querySelector('[data-panel]');
    const panelImg = desk.querySelector('[data-panel-img]');
    const panelNext = desk.querySelector('[data-panel-next]');

    // Like Isla 1.1.11, the island grows wide first and then drops down; closing, it folds up
    // and then draws in. Two registered properties let width and height ride their own curves.
    if (window.CSS && CSS.registerProperty) {
      try {
        CSS.registerProperty({ name: '--px', syntax: '<percentage>', inherits: false, initialValue: '41.4%' });
        CSS.registerProperty({ name: '--pb', syntax: '<percentage>', inherits: false, initialValue: '90%' });
        CSS.registerProperty({ name: '--ix', syntax: '<percentage>', inherits: false, initialValue: '35.5%' });
        CSS.registerProperty({ name: '--iy', syntax: '<percentage>', inherits: false, initialValue: '60%' });
        desk.classList.add('axes');
      } catch (error) { /* already registered or unsupported: the plain clip-path transition stays */ }
    }
    const actLayer = desk.querySelector('[data-act-layer]');
    const actImg = desk.querySelector('[data-act-img]');
    const hint = desk.querySelector('[data-hint]');
    const tabButtons = [...document.querySelectorAll('[data-tabs] [data-tab]')];
    const styleButtons = [...document.querySelectorAll('[data-styles] [data-style]')];
    const actButtons = [...document.querySelectorAll('[data-act]')];

    const tabs = ['home', 'agents', 'shelf', 'clipboard', 'calendar', 'tasks', 'timers', 'notes', 'teleprompter', 'terminal', 'home-actions', 'dragging'];
    const activities = {
      media: { x: 436, w: 640, h: 80 }, airpods: {}, charging: {}, volume: {}, brightness: {}, meeting: {}, download: {}, caps: {}, timerdone: {}, shelf: {},
      track: { h: 100 }, lyrics: { x: 376, w: 760, h: 100 }, agents: {},
    };
    let style = 'glass';
    let tab = 'home';
    let pinned = false;
    let closeTimer;
    let actTimer;

    const src = (name) => `assets/app/${style}-${name}.jpg`;
    const preload = (url) => { const image = new Image(); image.src = url; };
    let preloaded = false;
    function preloadAll() {
      if (preloaded) return;
      preloaded = true;
      ['glass', 'classic'].forEach((s) => tabs.forEach((t) => preload(`assets/app/${s}-${t}.jpg`)));
      Object.keys(activities).forEach((a) => preload(`assets/app/act-${a}.jpg`));
    }
    new IntersectionObserver((entries, observer) => {
      if (entries.some((entry) => entry.isIntersecting)) { preloadAll(); observer.disconnect(); }
    }, { rootMargin: '600px' }).observe(desk);

    // A new tab cross-fades over the old one, so the parts they share (the header, the
    // wallpaper) stay perfectly still and only what changes melts into place.
    let swapToken = 0;
    function setPanelImage(name) {
      const next = src(name);
      const token = ++swapToken;
      if (panelImg.getAttribute('src') === next) { panelNext?.classList.remove('in'); return; }
      const wasOpen = desk.dataset.state === 'open';
      const image = new Image();
      image.onload = () => {
        if (token !== swapToken) return;
        if (!wasOpen || !panelNext || reduceMotion) { panelImg.src = next; return; }
        panelNext.src = next;
        panelNext.classList.add('in');
        setTimeout(() => {
          if (token !== swapToken) return;
          panelImg.src = next;
          // Give the base image a moment to paint before the overlay goes.
          setTimeout(() => { if (token === swapToken) panelNext.classList.remove('in'); }, 80);
        }, 300);
      };
      image.src = next;
    }

    function markTab(name) {
      tabButtons.forEach((button) => button.classList.toggle('is-on', button.dataset.tab === name));
      placeAll(true);
    }

    function open(name = tab, { pin = false } = {}) {
      clearTimeout(closeTimer);
      endActivity(true);
      tab = name;
      pinned = pinned || pin;
      setPanelImage(name);
      if (name !== 'dragging') markTab(name);
      desk.dataset.state = 'open';
    }

    function close() {
      pinned = false;
      desk.dataset.state = 'closed';
      showActivity('media', true);
    }

    function endActivity(silent) {
      clearTimeout(actTimer);
      if (silent) { actToken++; delete desk.dataset.actOn; }
    }

    let actToken = 0;
    function showActivity(name, persistent = false) {
      const config = { x: 436, w: 640, h: 80, ...activities[name] };
      const notchWidth = 185;
      const token = ++actToken;
      const wasOn = 'actOn' in desk.dataset;
      if (desk.dataset.state === 'open') desk.dataset.state = 'closed';
      delete desk.dataset.actOn;
      // The ears on show leave quickly, then the new activity grows out of the notch.
      setTimeout(() => {
        if (token !== actToken) return;
        actLayer.classList.add('reset');
        actLayer.style.left = `${(config.x / 1512) * 100}%`;
        actLayer.style.width = `${(config.w / 1512) * 100}%`;
        actLayer.style.setProperty('--ix0', `${((config.w - notchWidth) / 2 / config.w) * 100}%`);
        actLayer.style.setProperty('--iy0', `${(1 - 32 / config.h) * 100}%`);
        actImg.src = `assets/app/act-${name}.jpg`;
        actImg.width = config.w * 2;
        actImg.height = config.h * 2;
        void actLayer.offsetWidth;
        actLayer.classList.remove('reset');
        // Wait for the picture (they are preloaded, so this is usually at once), never more than 300 ms.
        const ready = new Promise((resolve) => {
          if (actImg.complete) { resolve(); return; }
          actImg.addEventListener('load', resolve, { once: true });
          actImg.addEventListener('error', resolve, { once: true });
          setTimeout(resolve, 300);
        });
        ready.then(() => setTimeout(() => { if (token === actToken && desk.dataset.state !== 'open') desk.dataset.actOn = ''; }, 16));
      }, wasOn ? 170 : 0);
      clearTimeout(actTimer);
      actButtons.forEach((button) => button.classList.toggle('is-on', !persistent && button.dataset.act === name));
      if (!persistent) {
        actTimer = setTimeout(() => {
          actButtons.forEach((button) => button.classList.remove('is-on'));
          showActivity('media', true);
        }, name === 'meeting' || name === 'lyrics' ? 4200 : 3000);
      }
    }

    // The captured session is playing music, so the island starts with it.
    showActivity('media', true);
    updateClock();
    setInterval(updateClock, 20000);

    const notchHit = desk.querySelector('[data-open]');
    notchHit.addEventListener('click', () => (desk.dataset.state === 'open' ? close() : open('home')));
    if (canHover) {
      notchHit.addEventListener('mouseenter', () => { if (desk.dataset.state !== 'open') open('home'); });
      desk.addEventListener('mouseleave', () => {
        if (pinned || desk.dataset.state !== 'open' || dragging) return;
        closeTimer = setTimeout(close, 650);
      });
      desk.addEventListener('mouseenter', () => clearTimeout(closeTimer));
    }
    desk.querySelector('.desk-wall').addEventListener('click', () => { if (desk.dataset.state === 'open') close(); });

    panel.querySelectorAll('[data-tab]').forEach((button) => {
      button.addEventListener('click', (event) => { event.stopPropagation(); open(button.dataset.tab, { pin: true }); });
    });
    tabButtons.forEach((button) => button.addEventListener('click', () => open(button.dataset.tab, { pin: true })));
    styleButtons.forEach((button) => button.addEventListener('click', () => {
      style = button.dataset.style;
      desk.dataset.style = style;
      styleButtons.forEach((b) => b.classList.toggle('is-on', b === button));
      placeAll(true);
      if (desk.dataset.state === 'open') { setPanelImage(tab); } else { open(tab, { pin: true }); }
    }));
    actButtons.forEach((button) => button.addEventListener('click', (event) => {
      event.stopPropagation();
      pinned = false;
      showActivity(button.dataset.act);
    }));
    document.addEventListener('keydown', (event) => { if (event.key === 'Escape' && desk.dataset.state === 'open') close(); });

    /* Drag files onto the notch */
    let dragging = null;
    const files = [...desk.querySelectorAll('.file')];

    function notchPoint() {
      const canvas = desk.querySelector('.desk-canvas').getBoundingClientRect();
      return { x: canvas.left + canvas.width / 2, y: canvas.top + canvas.width * 0.012, reach: canvas.width * 0.2 };
    }

    files.forEach((file) => {
      file.addEventListener('dragstart', (event) => event.preventDefault());
      file.addEventListener('pointerdown', (event) => {
        if (event.button !== 0) return;
        event.preventDefault();
        file.setPointerCapture(event.pointerId);
        const ghost = file.querySelector('.file-icon').cloneNode(true);
        ghost.classList.add('file-ghost');
        const rect = file.querySelector('.file-icon').getBoundingClientRect();
        ghost.style.width = `${rect.width}px`;
        ghost.style.height = `${rect.height}px`;
        ghost.style.left = `${event.clientX}px`;
        ghost.style.top = `${event.clientY}px`;
        document.body.appendChild(ghost);
        file.style.opacity = '0.35';
        hint?.classList.add('is-hidden');
        dragging = { file, ghost, near: false };
        endActivity(true);
      });
      file.addEventListener('pointermove', (event) => {
        if (!dragging || dragging.file !== file) return;
        dragging.ghost.style.left = `${event.clientX}px`;
        dragging.ghost.style.top = `${event.clientY}px`;
        const target = notchPoint();
        const near = Math.hypot(event.clientX - target.x, event.clientY - target.y) < target.reach;
        if (near !== dragging.near) {
          dragging.near = near;
          if (near) { open('dragging'); } else { desk.dataset.state = 'closed'; }
        }
      });
      const finish = () => {
        if (!dragging || dragging.file !== file) return;
        const { ghost, near } = dragging;
        dragging = null;
        ghost.remove();
        file.style.opacity = '';
        if (near) {
          file.classList.add('is-gone');
          open('shelf', { pin: true });
          setTimeout(() => {
            if (desk.dataset.state === 'open' && tab === 'shelf') { pinned = false; desk.dataset.state = 'closed'; showActivity('shelf'); }
          }, 1800);
          if (files.every((f) => f.classList.contains('is-gone'))) {
            setTimeout(() => { files.forEach((f) => f.classList.remove('is-gone')); hint?.classList.remove('is-hidden'); }, 6000);
          }
        } else {
          close();
        }
      };
      file.addEventListener('pointerup', finish);
      file.addEventListener('pointercancel', finish);
    });
  }

  /* ---------------- Before / after ---------------- */

  document.querySelectorAll('[data-ba]').forEach((ba) => {
    const range = ba.querySelector('[data-ba-range]');
    range.addEventListener('input', () => ba.style.setProperty('--pos', `${range.value}%`));
  });

  /* ---------------- Marquee duplicate ---------------- */

  const track = document.querySelector('.marquee-track');
  if (track) track.append(...[...track.children].map((node) => node.cloneNode(true)));

  /* ---------------- Reveal ---------------- */

  if (!reduceMotion && 'IntersectionObserver' in window) {
    const groups = [
      ['.section-head', ['.h2', '.lead', '.quote', '.quote-by', '.pill-link']],
      ['.demo', ['.screen', '.demo-controls', '.acts', '.demo-after']],
      ['.bento', ['.tile']],
      ['.mini-grid', ['.mini']],
      ['.made', ['.stats div', '.tech', '.native-text', '.shot-a', '.shot-b']],
      ['.compare', ['.ba']],
      ['.plans', ['.plan']],
      ['.promises', ['.promise']],
      ['.includes', ['.h3', '.cmp', '.cmp-note']],
      ['.final', ['.stage', '.h1', '.lead', '.hero-ctas', '.hero-meta']],
      ['.faq-list', ['details']],
      ['.release', ['.release-version', '.release-date', '.release-badge', '.release-intro', '.release-shot', 'li', '.release-links']],
      ['.log', ['.log-foot']],
    ];
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.querySelectorAll('.reveal').forEach((node) => node.classList.add('in'));
        entry.target.querySelectorAll('[data-count]').forEach(countUp);
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px' });

    // The figures roll up to their value once, as the stats come into view.
    function countUp(node) {
      const target = Number(node.dataset.count);
      const suffix = node.dataset.suffix || '';
      const start = performance.now();
      const step = (now) => {
        const t = Math.min(1, (now - start) / 1100);
        const eased = 1 - Math.pow(1 - t, 3);
        node.textContent = `${Math.round(target * eased)}${suffix}`;
        if (t < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    }
    groups.forEach(([selector, parts]) => {
      document.querySelectorAll(selector).forEach((section) => {
        let i = 0;
        parts.forEach((part) => section.querySelectorAll(part).forEach((node) => {
          if (node.classList.contains('reveal')) return;
          node.classList.add('reveal');
          node.style.setProperty('--i', String(i++ % 8));
        }));
        observer.observe(section);
      });
    });
  }

  /* ---------------- Cocuyos (fireflies) ---------------- */

  const sky = document.querySelector('[data-cocuyos]');
  if (sky && !reduceMotion) {
    const context = sky.getContext('2d');
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    let flies = [];
    const resize = () => {
      sky.width = innerWidth * ratio;
      sky.height = innerHeight * ratio;
      const count = Math.round(Math.min(46, innerWidth / 30));
      flies = Array.from({ length: count }, () => ({
        x: Math.random() * innerWidth, y: Math.random() * innerHeight,
        vx: (Math.random() - 0.5) * 0.25, vy: (Math.random() - 0.5) * 0.2,
        phase: Math.random() * Math.PI * 2, speed: 0.6 + Math.random() * 1.2, size: 1 + Math.random() * 1.6,
      }));
    };
    resize();
    addEventListener('resize', resize, { passive: true });
    let running = true;
    document.addEventListener('visibilitychange', () => { running = !document.hidden; if (running) requestAnimationFrame(tick); });
    function tick(time) {
      if (!running) return;
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      context.clearRect(0, 0, innerWidth, innerHeight);
      for (const fly of flies) {
        fly.x += fly.vx + Math.sin(time / 2400 + fly.phase) * 0.12;
        fly.y += fly.vy + Math.cos(time / 2800 + fly.phase) * 0.1;
        if (fly.x < -10) fly.x = innerWidth + 10; if (fly.x > innerWidth + 10) fly.x = -10;
        if (fly.y < -10) fly.y = innerHeight + 10; if (fly.y > innerHeight + 10) fly.y = -10;
        const glow = Math.max(0, Math.sin(time / 1000 * fly.speed + fly.phase));
        if (glow < 0.05) continue;
        const radius = fly.size * 5;
        const light = context.createRadialGradient(fly.x, fly.y, 0, fly.x, fly.y, radius);
        light.addColorStop(0, `rgba(226, 255, 150, ${0.75 * glow})`);
        light.addColorStop(0.35, `rgba(200, 255, 120, ${0.25 * glow})`);
        light.addColorStop(1, 'rgba(200, 255, 120, 0)');
        context.fillStyle = light;
        context.beginPath(); context.arc(fly.x, fly.y, radius, 0, Math.PI * 2); context.fill();
      }
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  applyLanguage();
})();
