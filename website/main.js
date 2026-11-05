/* Isla website: language, the menu bar island, live desktop demo, comparisons and motion. */
(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const canHover = window.matchMedia('(hover: hover)').matches;

  /* ---------------- Language ---------------- */

  const en = {
    'skip': 'Skip to content',
    'nav.try': 'Try it', 'nav.features': 'Features', 'nav.news': 'What’s new', 'nav.free': 'Free', 'nav.open': 'Open source', 'nav.faq': 'FAQ', 'nav.download': 'Download',
    'island.label': 'What’s new',
    'hero.title1': 'Your notch, now', 'hero.title2': 'an island.',
    'hero.sub': 'Music with lyrics, a Shelf with AirDrop, calendar, clipboard, terminal and live activities, right under your camera. Native, in Liquid Glass. Free and open source.',
    'hero.cta': 'Download free', 'hero.try': 'Try it here',
    'hero.meta': 'macOS 26 Tahoe or later · Apple silicon and Intel · With or without a notch',
    'demo.title': 'Try it before you download it.',
    'demo.lead': 'This is the real Isla, captured on a MacBook Pro. Point at the notch, switch tabs, drag a file or turn on a live activity.',
    'demo.openAria': 'Open the Nook', 'demo.hint': 'Psst… it’s interactive. Drag a file to the notch.',
    'mb.file': 'File', 'mb.edit': 'Edit',
    'tab.home': 'Nook', 'tab.shelf': 'Shelf', 'tab.clipboard': 'Clipboard', 'tab.calendar': 'Calendar', 'tab.tasks': 'Tasks',
    'tab.timers': 'Focus', 'tab.notes': 'Notes', 'tab.teleprompter': 'Teleprompter', 'tab.terminal': 'Terminal', 'tab.actions': 'Actions',
    'style.classic': 'Classic',
    'act.airpods': 'Connect AirPods', 'act.charging': 'Plug in the charger', 'act.volume': 'Turn up the volume', 'act.brightness': 'Dim the screen',
    'act.meeting': 'Meeting in 4 min', 'act.download': 'Download a file', 'act.track': 'Change the song', 'act.lyrics': 'Lyrics under the island',
    'act.timer': 'Pomodoro done', 'act.caps': 'Caps Lock',
    'live.title': 'The island keeps you posted.',
    'live.lead': 'Charging, AirPods with their battery, volume and brightness, downloads, meetings, timers and your song. They appear around the notch and leave on their own.',
    'features.title1': 'More than 40 features.', 'features.title2': 'Zero price.',
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
    'm.weather.t': 'Weather', 'm.weather.p': 'Local, with highs and lows.', 'm.hud.t': 'Volume HUD', 'm.hud.p': 'Replaces the system overlay.',
    'm.gestures.t': 'Gestures', 'm.gestures.p': 'Swipe to open or change songs.', 'm.screens.t': 'Every display', 'm.screens.p': 'Notched, notchless and external monitors.',
    'm.keys.t': 'Keyboard', 'm.keys.p': '⌃⌥Space opens the island from any app.', 'm.lang.t': 'English and Spanish', 'm.lang.p': 'Fully translated.',
    'm.privacy.t': 'Private', 'm.privacy.p': 'No accounts, no analytics.', 'm.updates.t': 'Always up to date', 'm.updates.p': 'Lets you know when a new version ships.',
    'compare.title': 'Glass or black. Your call.',
    'compare.lead': 'macOS Liquid Glass lets your wallpaper shine through the island. Classic black melts it into the camera. Slide to compare.',
    'native.title': 'Made the way Apple would.',
    'native.lead': 'Swift and SwiftUI, the system Liquid Glass, SF Symbols, haptics and a Settings window that feels like System Settings. No Electron, no web views.',
    'stats.native': 'native', 'stats.size': 'download', 'stats.trackers': 'trackers',
    'free.title': 'Everything included. Free. Forever.',
    'free.lead': 'No Pro tier, no 48-hour trial, no subscription and no limit on Macs.',
    'free.note': 'Forever, on every Mac you own.', 'free.cta': 'Download Isla',
    'free.l1': 'Liquid Glass or classic black', 'free.l2': 'Music with synced lyrics', 'free.l3': 'Shelf, AirDrop and Pocket', 'free.l4': 'On-device file conversion',
    'free.l5': 'Clipboard history', 'free.l6': 'Calendar, tasks and notes', 'free.l7': 'Pomodoro and focus sounds', 'free.l8': 'A teleprompter that follows your voice',
    'free.l9': 'A terminal inside the notch', 'free.l10': 'Every live activity', 'free.l11': 'Works on Macs without a notch', 'free.l12': 'Every update',
    'open.title': 'Open, like the sea.',
    'open.lead': 'Isla is free and open source under the MIT License. Read the code, suggest improvements or build your own.',
    'open.made': 'Designed and built by Kyros Solutions RD in Santo Domingo, on an island in the Caribbean. Hence the name.',
    'open.cta': 'View on GitHub', 'open.contrib': 'How to contribute', 'code.c1': 'Build Isla in a minute',
    'open.caption': 'Calle las Damas, in Santo Domingo’s Colonial Zone, a short walk from where Isla was born.',
    'faq.title': 'Questions, answered.',
    'faq.q1': 'Is Isla really free?', 'faq.a1': 'Yes. Every feature is free, forever, with no trial and no subscription. The code is on GitHub under the MIT License.',
    'faq.q2': 'Which Mac do I need?', 'faq.a2': 'Any Mac running macOS 26 Tahoe or later, with Apple silicon or Intel. Isla uses the system Liquid Glass, which is why it requires Tahoe.',
    'faq.q3': 'What if my Mac has no notch?', 'faq.a3': 'Isla draws a matching island at the top of any display, external monitors included. You choose which displays show it.',
    'faq.q4': 'Which music apps does it work with?', 'faq.a4': 'Any app that shows up in Control Center’s Now Playing: Music, Spotify, Podcasts, YouTube in the browser and more. Lyrics come from LRCLIB, an open database.',
    'faq.q5': 'What permissions does it ask for, and what happens to my data?', 'faq.a5': 'Only the ones you turn on: Calendar, Reminders, Camera for the Mirror, Location for weather, Microphone for the teleprompter and Accessibility for the volume overlay. Nothing leaves your Mac except the weather lookup with an approximate location, the lyrics search and the update check.',
    'faq.q6': 'macOS says it can’t verify the app. What do I do?', 'faq.a6': 'Community builds are signed without a paid Apple certificate. Open System Settings › Privacy & Security, scroll down, click “Open Anyway” and confirm. You only do this once. Or build it yourself from source.',
    'faq.q7': 'How do I hear about new versions?', 'faq.a7': 'Isla checks for updates once a day and tells you right on the island; they install in one click. Everything that changes is in <a href="novedades/">What’s new</a>. You can turn the check off in Settings.',
    'final.title': 'Your notch awaits.', 'final.lead': 'Open the .dmg, drag Isla to Applications and move the pointer to the notch.', 'final.cta': 'Download free',
    'footer.tag': 'Your notch, now an island. Made in Santo Domingo.', 'footer.product': 'Product', 'footer.resources': 'Resources', 'footer.community': 'Community',
    'footer.releases': 'Releases', 'footer.changelog': 'What’s new', 'footer.issues': 'Report an issue', 'footer.contribute': 'Contribute',
    'footer.license': 'MIT License', 'footer.tm': 'Mac, macOS, AirPods and AirDrop are trademarks of Apple Inc. Isla is not affiliated with Apple.',
    'footer.photos': 'Photos:', 'footer.bg': 'background of the captures',
    'log.title': 'What’s new',
    'log.lead': 'Everything that changes in Isla, version by version. The app updates itself and lets you know on the island; here you can see what each version brings.',
    'log.cta': 'Download Isla', 'log.feed': 'Subscribe via RSS', 'log.list': 'Every version',
    'log.foot': 'Looking for something more technical? Every version is also on',
  };

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
    const titles = document.documentElement.dataset;
    document.title = lang === 'en' ? (titles.titleEn || document.title) : (titles.titleEs || document.title);
    updateClock();
    updateBarClock();
    document.dispatchEvent(new CustomEvent('isla:lang', { detail: lang }));
  }

  toggle?.addEventListener('click', () => {
    lang = lang === 'en' ? 'es' : 'en';
    localStorage.setItem('isla-lang', lang);
    applyLanguage();
  });

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
    const actLayer = desk.querySelector('[data-act-layer]');
    const actImg = desk.querySelector('[data-act-img]');
    const hint = desk.querySelector('[data-hint]');
    const tabButtons = [...document.querySelectorAll('[data-tabs] [data-tab]')];
    const styleButtons = [...document.querySelectorAll('[data-styles] [data-style]')];
    const actButtons = [...document.querySelectorAll('[data-act]')];

    const tabs = ['home', 'shelf', 'clipboard', 'calendar', 'tasks', 'timers', 'notes', 'teleprompter', 'terminal', 'home-actions', 'dragging'];
    const activities = {
      media: { x: 436, w: 640, h: 80 }, airpods: {}, charging: {}, volume: {}, brightness: {}, meeting: {}, download: {}, caps: {}, timerdone: {}, shelf: {},
      track: { h: 100 }, lyrics: { x: 376, w: 760, h: 100 },
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

    function setPanelImage(name) {
      const next = src(name);
      if (panelImg.getAttribute('src') === next) return;
      panelImg.classList.add('swap');
      const image = new Image();
      image.onload = () => { panelImg.src = next; requestAnimationFrame(() => panelImg.classList.remove('swap')); };
      image.src = next;
    }

    function markTab(name) {
      tabButtons.forEach((button) => button.classList.toggle('is-on', button.dataset.tab === name));
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
      if (silent) delete desk.dataset.actOn;
    }

    function showActivity(name, persistent = false) {
      const config = { x: 436, w: 640, h: 80, ...activities[name] };
      const notchWidth = 185;
      actLayer.style.left = `${(config.x / 1512) * 100}%`;
      actLayer.style.width = `${(config.w / 1512) * 100}%`;
      actLayer.style.setProperty('--ix', `${((config.w - notchWidth) / 2 / config.w) * 100}%`);
      actLayer.style.setProperty('--iy', `${(1 - 32 / config.h) * 100}%`);
      if (desk.dataset.state === 'open') desk.dataset.state = 'closed';
      delete desk.dataset.actOn;
      actImg.src = `assets/app/act-${name}.jpg`;
      actImg.width = config.w * 2;
      actImg.height = config.h * 2;
      setTimeout(() => { desk.dataset.actOn = ''; }, 30);
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
      ['.section-head', ['.h2', '.lead']],
      ['.demo', ['.desk', '.demo-controls', '.acts']],
      ['.bento', ['.tile']],
      ['.mini-grid', ['.mini']],
      ['.compare', ['.ba']],
      ['.native', ['.h2', '.lead', '.stats', '.shot-a', '.shot-b']],
      ['.free', ['.price']],
      ['.open', ['.open-photo', '.h2', '.lead', '.body', '.open-ctas', '.code', '.open-street']],
      ['.faq-list', ['details']],
      ['.final', ['.final-icon', '.h1', '.lead', '.btn']],
      ['.release', ['.release-version', '.release-date', '.release-badge', '.release-intro', '.release-shot', 'li', '.release-links']],
      ['.log', ['.log-foot']],
    ];
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.querySelectorAll('.reveal').forEach((node) => node.classList.add('in'));
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px' });
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

  applyLanguage();
})();
