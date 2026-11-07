/* Isla website: language, the menu bar island, live desktop demo, comparisons and motion. */
(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  // A page change the browser decides not to animate (a hidden tab) is not an error worth reporting.
  const quiet = (event) => {
    const transition = event.viewTransition;
    if (transition) [transition.ready, transition.finished, transition.updateCallbackDone].forEach((promise) => promise?.catch(() => {}));
  };
  addEventListener('pageswap', quiet);
  addEventListener('pagereveal', quiet);
  const canHover = window.matchMedia('(hover: hover)').matches;

  /* ---------------- Language ---------------- */

  const en = {
    'skip': 'Skip to content',
    'nav.badge': 'Free', 'nav.try': 'Try it', 'nav.new': 'New', 'nav.features': 'Features', 'nav.free': 'Price', 'nav.news': 'What’s new', 'nav.faq': 'FAQ', 'nav.download': 'Download',
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
    'tab.agents': 'AI', 'act.agents': 'An agent at work', 'act.call': 'An incoming call',
    'b.agents.t': 'Your AI agents, in sight', 'b.agents.p': 'Codex, Gemini CLI, Antigravity and the other agents working on your Mac: which folder, since when, what they are doing now and whether they need you. Plus the models Ollama and LM Studio keep in memory. No permissions, and nothing leaves your Mac.',
    'style.classic': 'Classic',
    'act.airpods': 'Connect AirPods', 'act.charging': 'Plug in the charger', 'act.volume': 'Turn up the volume', 'act.brightness': 'Dim the screen',
    'act.meeting': 'Meeting in 4 min', 'act.download': 'Download a file', 'act.track': 'Change the song', 'act.lyrics': 'Lyrics under the island',
    'act.timer': 'Pomodoro done', 'act.caps': 'Caps Lock',
    'live.title': 'The island keeps you posted.',
    'live.lead': 'Charging, AirPods with their battery, volume and brightness, downloads, calls, meetings, timers, your AI agents and your song. They appear around the notch and leave on their own; when two happen at once, the second waits in a bubble.',
    'news.title': 'Search, ask, watch and answer.',
    'news.lead': 'New in version 1.1.14: four features that live under the camera, without opening another app and without anything leaving your Mac.',
    'news.listAria': 'New in 1.1.14',
    'news.search.t': 'Search', 'news.search.p': 'Apps, files, the calculator and currencies. Type “100 usd to dop” and Return copies the answer.',
    'news.chat.t': 'Local AI chat', 'news.chat.p': 'Talk to your Ollama or LM Studio models as the answer streams in. Only with the server on your Mac.',
    'news.system.t': 'System monitor', 'news.system.p': 'CPU and network with a graph, memory and free disk in a Nook widget, plus optional ears with the notch closed.',
    'news.call.t': 'Calls on the island', 'news.call.p': 'FaceTime or your iPhone rings on the island, with large Accept and Decline buttons.',
    'news.search.alt': 'Search with “100 usd a dop” typed and the answer in Dominican pesos',
    'news.chat.alt': 'Chat with a local Ollama model answering under the notch',
    'news.system.alt': 'The Nook with the System widget: CPU, memory, network and disk',
    'news.call.alt': 'An incoming call on the island with Decline and Accept buttons',
    'm.notif.t': 'Notifications', 'm.notif.p': 'WhatsApp, Messages and Mail, on the island.',
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
    'm.search.t': 'Search', 'm.search.p': '⌃⌥K: apps, files, a calculator and currencies.',
    'm.chat.t': 'Local AI chat', 'm.chat.p': 'Your Ollama or LM Studio models, offline.',
    'm.system.t': 'System monitor', 'm.system.p': 'Live CPU, memory, network and disk.',
    'm.calls.t': 'Calls on the island', 'm.calls.p': 'Accept or decline FaceTime and iPhone calls.',
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
    'plan.a.kicker': 'Ready to use',
    'plan.a.text': 'The one we recommend: download the .dmg, drag it to Applications and you’re done. It updates itself, signed and verified.',
    'plan.a.note': 'free, forever', 'plan.a.chip': 'On every Mac you own', 'plan.a.cta': 'Download Isla',
    'plan.a.foot': 'Version <span data-latest></span> · see what’s new ↗',
    'plan.b.kicker': 'To build it yourself',
    'plan.b.text': 'The same code, on GitHub under the MIT License. Read it, change it or make your own version.',
    'plan.b.note': 'open source', 'plan.b.chip': 'Xcode 26 and XcodeGen', 'plan.b.cta': 'View on GitHub', 'plan.b.foot': 'How to contribute ↗',
    'free.l1': 'Liquid Glass or classic black', 'free.l2': 'Music with synced lyrics', 'free.l3': 'Shelf, AirDrop and Pocket',
    'free.l5': 'Clipboard history', 'free.l6': 'Calendar, tasks and notes', 'free.l8': 'A teleprompter that follows your voice',
    'free.l9': 'A terminal inside the notch', 'free.l12': 'Every update',
    'promise.1.t': 'No account', 'promise.1.p': 'No email, sign-up or card. You download it and use it.',
    'promise.2.t': 'No tracking', 'promise.2.p': 'Zero analytics. Only the weather, lyrics, exchange rates and update check leave your Mac.',
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
    'faq.q5': 'What permissions does it ask for, and what happens to my data?', 'faq.a5': 'Only the ones you turn on: Calendar, Reminders, Camera for the Mirror, Location for weather, Microphone for the teleprompter and Accessibility for the volume overlay, notifications and calls. Nothing leaves your Mac except the weather lookup with an approximate location, the lyrics search, exchange rates when you convert a currency and the update check. Chat only talks to Ollama or LM Studio on your Mac.',
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
    'log.cta': 'Download Isla', 'log.feed': 'Subscribe via RSS', 'log.list': 'Every version', 'log.jump': 'Go to a version',
    'log.foot': 'Looking for something more technical? Every version is also on',
  };

  const latestVersion = document.querySelector('[data-latest]')?.textContent.trim() || '';
  const nodes = [...document.querySelectorAll('[data-i18n]')];
  const original = new Map(nodes.map((node) => [node, node.textContent]));
  const ariaNodes = [...document.querySelectorAll('[data-i18n-aria]')];
  const originalAria = new Map(ariaNodes.map((node) => [node, node.getAttribute('aria-label')]));
  const altNodes = [...document.querySelectorAll('[data-i18n-alt]')];
  const originalAlt = new Map(altNodes.map((node) => [node, node.getAttribute('alt')]));
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
    altNodes.forEach((node) => node.setAttribute('alt', lang === 'en' && en[node.dataset.i18nAlt] ? en[node.dataset.i18nAlt] : originalAlt.get(node)));
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
      const transition = document.startViewTransition(applyLanguage);
      [transition.ready, transition.finished, transition.updateCallbackDone].forEach((promise) => promise?.catch(() => {}));
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

  /* ---------------- The notch's links: a plate follows the section you are reading ---------------- */

  const navLinks = document.querySelector('[data-navlinks]');
  if (navLinks && 'IntersectionObserver' in window) {
    const plate = document.createElement('span');
    plate.className = 'nav-thumb';
    plate.setAttribute('aria-hidden', 'true');
    navLinks.prepend(plate);
    const links = [...navLinks.querySelectorAll('a[href^="#"]')];
    const sections = links.map((link) => document.querySelector(link.getAttribute('href'))).filter(Boolean);
    let current = null;
    const placePlate = (link, animated = true) => {
      if (!link || !link.offsetWidth) { plate.classList.remove('on'); return; }
      if (!animated) plate.style.transition = 'none';
      plate.style.setProperty('--tx', `${link.offsetLeft}px`);
      plate.style.setProperty('--tw', `${link.offsetWidth}px`);
      plate.style.setProperty('--th', `${link.offsetHeight}px`);
      plate.style.top = `${link.offsetTop}px`;
      if (!animated) { void plate.offsetWidth; plate.style.transition = ''; }
      plate.classList.add('on');
    };
    const mark = (id) => {
      const link = links.find((l) => l.getAttribute('href') === `#${id}`) || null;
      if (link === current) return;
      const first = !current || !plate.classList.contains('on');
      current = link;
      links.forEach((l) => l.classList.toggle('is-here', l === link));
      placePlate(link, !first);
    };
    // A section counts as "in view" while it crosses the middle of the window.
    const spy = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) mark(entry.target.id); });
      if (window.scrollY < innerHeight * 0.5) mark('');
    }, { rootMargin: '-45% 0px -54% 0px' });
    sections.forEach((section) => spy.observe(section));
    // Past the questions, the page is closing: no link is "here" any more.
    document.querySelectorAll('.final').forEach((section) => spy.observe(section));
    addEventListener('resize', () => placePlate(current, false), { passive: true });
    document.addEventListener('isla:lang', () => requestAnimationFrame(() => placePlate(current, false)));
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
      track: { h: 100 }, lyrics: { x: 376, w: 760, h: 100 }, agents: {}, call: { h: 90 },
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

    // Once someone has played with the demo, the island stops inviting them to.
    const touch = () => { desk.dataset.touched = ''; };

    function open(name = tab, { pin = false } = {}) {
      touch();
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
      const duration = name === 'meeting' || name === 'lyrics' || name === 'call' ? 4200 : 3000;
      actButtons.forEach((button) => {
        const on = !persistent && button.dataset.act === name;
        // Restart the fill even when the same activity is shown twice in a row.
        if (on && button.classList.contains('is-on')) { button.classList.remove('is-on'); void button.offsetWidth; }
        button.style.setProperty('--dur', `${duration}ms`);
        button.classList.toggle('is-on', on);
      });
      if (!persistent) {
        touch();
        actTimer = setTimeout(() => {
          actButtons.forEach((button) => button.classList.remove('is-on'));
          showActivity('media', true);
        }, duration);
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
        dragging = { file, ghost, near: false, home: { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 } };
        touch();
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
      // The ghost leaves with a gesture: swallowed by the notch, or sliding back to its place.
      const fly = (ghost, to, into) => {
        const from = 'translate(-50%, -50%) rotate(-4deg)';
        if (reduceMotion || !ghost.animate) { ghost.remove(); return; }
        const dx = to.x - parseFloat(ghost.style.left);
        const dy = to.y - parseFloat(ghost.style.top);
        const end = into
          ? { transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(0.2)`, opacity: 0 }
          : { transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) rotate(0deg)`, opacity: 0.2 };
        const motion = ghost.animate([{ transform: from, opacity: 0.95 }, end], { duration: into ? 340 : 420, easing: into ? 'cubic-bezier(0.55, 0, 0.75, 0.2)' : 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'forwards' });
        motion.onfinish = () => ghost.remove();
      };
      const finish = () => {
        if (!dragging || dragging.file !== file) return;
        const { ghost, near, home } = dragging;
        dragging = null;
        const target = notchPoint();
        fly(ghost, near ? { x: target.x, y: target.y } : home, near);
        if (near || reduceMotion) { file.style.opacity = ''; } else { setTimeout(() => { file.style.opacity = ''; }, 380); }
        if (near) {
          file.classList.add('is-gone');
          open('shelf', { pin: true });
          setTimeout(() => {
            if (desk.dataset.state === 'open' && tab === 'shelf') { pinned = false; desk.dataset.state = 'closed'; showActivity('shelf'); }
          }, 1800);
          if (files.every((f) => f.classList.contains('is-gone'))) {
            setTimeout(() => {
              files.forEach((f) => { f.classList.remove('is-gone'); f.classList.add('is-back'); setTimeout(() => f.classList.remove('is-back'), 600); });
              hint?.classList.remove('is-hidden');
            }, 6000);
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
    let touched = false;
    const set = (value) => { ba.style.setProperty('--pos', `${value}%`); range.value = String(Math.round(value)); };
    range.addEventListener('input', () => { touched = true; set(Number(range.value)); });
    // The first time it comes into view, the handle sweeps once each way to show it can be dragged.
    if (reduceMotion || !('IntersectionObserver' in window)) return;
    new IntersectionObserver((entries, observer) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      observer.disconnect();
      const keys = [[0, 50], [0.32, 34], [0.7, 64], [1, 50]];
      const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
      setTimeout(() => {
        const start = performance.now();
        const step = (now) => {
          if (touched) return;
          const t = Math.min(1, (now - start) / 1900);
          let k = 1;
          while (k < keys.length - 1 && t > keys[k][0]) k++;
          const [t0, v0] = keys[k - 1];
          const [t1, v1] = keys[k];
          set(v0 + (v1 - v0) * ease((t - t0) / (t1 - t0)));
          if (t < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
      }, 500);
    }, { threshold: 0.6 }).observe(ba);
  });

  /* ---------------- Marquee duplicate ---------------- */

  document.querySelectorAll('.marquee-track').forEach((track) => track.append(...[...track.children].map((node) => node.cloneNode(true))));

  /* ---------------- New in 1.1.14: one stage, four features ---------------- */

  const news = document.querySelector('[data-news]');
  if (news) {
    const items = [...news.querySelectorAll('[data-news-item]')];
    const shots = [...news.querySelectorAll('[data-news-shot]')];
    const hold = 6500;
    let index = 0;
    let timer;
    let startedAt = 0;
    let remaining = hold;
    let inView = false;
    let held = false;

    const run = () => {
      if (reduceMotion || !inView || held) { pause(); return; }
      if (!news.classList.contains('paused')) return;
      news.classList.remove('paused');
      items[index].classList.add('run');
      startedAt = performance.now();
      timer = setTimeout(() => select(index + 1), remaining);
    };
    const pause = () => {
      if (news.classList.contains('paused')) return;
      clearTimeout(timer);
      remaining = Math.max(400, remaining - (performance.now() - startedAt));
      news.classList.add('paused');
    };
    function select(next, focus = false) {
      index = (next + items.length) % items.length;
      const key = items[index].dataset.newsItem;
      items.forEach((item, n) => {
        const on = n === index;
        item.classList.toggle('is-on', on);
        item.classList.remove('run');
        item.setAttribute('aria-selected', String(on));
        item.tabIndex = on ? 0 : -1;
      });
      shots.forEach((shot) => {
        if (shot.dataset.newsShot === key && shot.loading === 'lazy') shot.loading = 'eager';
        shot.classList.toggle('is-on', shot.dataset.newsShot === key);
      });
      if (focus) items[index].focus();
      void news.offsetWidth;
      remaining = hold;
      news.style.setProperty('--dur', `${hold}ms`);
      news.classList.add('paused');
      run();
    }
    items.forEach((item, n) => {
      item.addEventListener('click', () => select(n));
      item.addEventListener('keydown', (event) => {
        const move = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
        if (move) { event.preventDefault(); select(index + move, true); }
      });
    });
    // Resting the pointer on the list, or tabbing into it, holds the current feature.
    const list = news.querySelector('.news-list');
    list.addEventListener('pointerenter', (event) => { if (event.pointerType === 'mouse') { held = true; pause(); } });
    list.addEventListener('pointerleave', (event) => { if (event.pointerType === 'mouse') { held = false; run(); } });
    news.addEventListener('focusin', () => { held = true; pause(); });
    news.addEventListener('focusout', (event) => { if (!news.contains(event.relatedTarget)) { held = false; run(); } });
    // Warm the other pictures once the section is near, so every switch is instant.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((entries, observer) => {
        if (entries.some((entry) => entry.isIntersecting)) { shots.forEach((shot) => { shot.loading = 'eager'; }); observer.disconnect(); }
      }, { rootMargin: '700px' }).observe(news);
      new IntersectionObserver((entries) => {
        inView = entries.some((entry) => entry.isIntersecting);
        if (inView) { run(); } else { pause(); }
      }, { threshold: 0.45 }).observe(news);
    }
    items.forEach((item, n) => { item.tabIndex = n === 0 ? 0 : -1; });
    news.style.setProperty('--dur', `${hold}ms`);
    news.classList.add('paused');
    if (!reduceMotion) news.classList.add('auto');
  }

  /* ---------------- Reveal ---------------- */

  if (!reduceMotion && 'IntersectionObserver' in window) {
    // [section, [[part, manner], ...]]: parts arrive in reading order, each kind in its own way.
    const groups = [
      ['.section-head', [['.h2', 'rv-title'], ['.lead'], ['.quote'], ['.quote-by', 'rv-sm'], ['.pill-link', 'rv-sm']]],
      ['.demo', [['.demo-controls'], ['.acts'], ['.demo-after']]],
      ['.news-body', [['.news-item', 'rv-sm']]],
      ['.bento', [['.tile', 'rv-tile']]],
      ['.mini-grid', [['.mini', 'rv-sm']]],
      ['.made', [['.stats div'], ['.tech', 'rv-sm'], ['.native-text', 'rv-left'], ['.shot-a', 'rv-pic'], ['.shot-b', 'rv-pic']]],
      ['.compare', [['.ba', 'rv-pic']]],
      ['.plans', [['.plan-main', 'rv-left'], ['.plan:not(.plan-main)', 'rv-right']]],
      ['.promises', [['.promise']]],
      ['.includes', [['.h3', 'rv-title'], ['.cmp', 'rv-pic'], ['.cmp-note', 'rv-sm']]],
      ['.faq-head', [['.h2', 'rv-title'], ['.lead'], ['.faq-more', 'rv-sm']]],
      ['.faq-list', [['details', 'rv-sm']]],
      ['.final', [['.h1', 'rv-title'], ['.lead'], ['.hero-ctas'], ['.hero-meta', 'rv-sm']]],
      ['.release', [['.release-version', 'rv-title'], ['.release-date', 'rv-sm'], ['.release-badge', 'rv-sm'], ['.release-intro'], ['.release-shot', 'rv-pic'], ['li', 'rv-sm'], ['.release-links', 'rv-sm']]],
      ['.log', [['.log-foot']]],
    ];

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

    // Once a part has arrived it gives its transitions back, so hovers answer at once.
    const settle = (node) => {
      const step = parseFloat(getComputedStyle(node).getPropertyValue('--step')) || 75;
      setTimeout(() => node.classList.remove('reveal', 'in', 'rv-title', 'rv-sm', 'rv-pic', 'rv-tile', 'rv-left', 'rv-right'), 1300 + Number(node.style.getPropertyValue('--i') || 0) * step);
    };
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.querySelectorAll('.reveal').forEach((node) => { node.classList.add('in'); settle(node); });
        entry.target.querySelectorAll('[data-count]').forEach(countUp);
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px' });

    groups.forEach(([selector, parts]) => {
      document.querySelectorAll(selector).forEach((section) => {
        let i = 0;
        parts.forEach(([part, manner]) => section.querySelectorAll(part).forEach((node) => {
          if (node.classList.contains('reveal')) return;
          node.classList.add('reveal');
          if (manner) node.classList.add(manner);
          node.style.setProperty('--i', String(i++ % 10));
        }));
        observer.observe(section);
      });
    });

    // Neon signs outside the hero switch on, with their flicker, as you reach them.
    const signs = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('lit'); signs.unobserve(entry.target); } });
    }, { rootMargin: '0px 0px -15% 0px' });
    document.querySelectorAll('.neon-side').forEach((sign) => signs.observe(sign));
  }

  /* ---------------- What's new: every version as a chip ---------------- */

  const jump = document.querySelector('[data-log-jump]');
  if (jump) {
    document.querySelectorAll('.release[id]').forEach((release, i) => {
      const link = document.createElement('a');
      link.href = `#${release.id}`;
      link.textContent = release.id.replace(/^v/, '');
      link.style.setProperty('--i', String(i));
      if (i === 0) link.classList.add('is-latest');
      jump.append(link);
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
