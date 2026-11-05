/* Isla website — language, hero reel, live notch demo, moments, entrances. */
(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- Language ---------- */

  const en = {
    'skip': 'Skip to content',
    'nav.features': 'Features', 'nav.try': 'Try it', 'nav.open': 'Open source', 'nav.faq': 'FAQ', 'nav.download': 'Download',
    'hero.left': 'Your notch,', 'hero.right': 'now an island.',
    'hero.lead': 'Music, files, calendar and live activities right under your camera. Native, in Liquid Glass, free and open source.',
    'hero.cta': 'Download free for Mac', 'hero.note': 'macOS 26 Tahoe or later · with or without a notch',
    'try.title': 'Point at the notch.',
    'try.lead': 'This is the real Isla, captured on a MacBook Pro. Open the Nook, switch tabs or trigger a live activity.',
    'try.openAria': 'Open the Nook',
    'try.nook': 'Open the Nook', 'try.airpods': 'Connect AirPods', 'try.charging': 'Plug in the charger', 'try.volume': 'Turn up the volume',
    'try.meeting': 'Meeting in 4 minutes', 'try.download': 'Download a file', 'try.track': 'Change the song', 'try.caps': 'Caps Lock',
    'features.title': 'Everything you use, one gesture away.',
    'f1.title': 'Music you can see', 'f1.text': 'Isla follows whatever plays in Music, Spotify, Podcasts or your browser. Artwork, controls, a scrubber and synced lyrics. Swipe sideways on the notch to change tracks.',
    'f2.title': 'Drop, keep, send', 'f2.text': 'Drag files onto the notch and they wait on the Shelf until you drop them anywhere. AirDrop them or convert them to PNG, JPEG, HEIC, PDF, MP4 or ZIP. Far from the notch? Shake the pointer and a Pocket appears.',
    'f3.title': 'Your week, without opening anything', 'f3.text': 'It reads the calendars already on your Mac (iCloud, Google, Exchange) and gives you a heads-up before every meeting with a button to join. Tasks sync with Reminders.',
    'f4.title': 'Everything you copied', 'f4.text': 'Clipboard history with search, filters and pinned items. Click to paste. Anything copied from a password manager is never saved.',
    'f5.title': 'Focus, and talk to camera', 'f5.text': 'Pomodoro, several timers at once, a stopwatch and brown noise generated on your Mac. Plus a teleprompter right under the lens that scrolls at your pace or follows your voice.',
    'moments.intro': 'The notch tells you about', 'moments.track': 'the song that just started,', 'moments.charging': 'your Mac charging,',
    'moments.airpods': 'your AirPods and their battery,', 'moments.volume': 'volume and brightness,', 'moments.download': 'your downloads,',
    'moments.meeting': 'your next meeting', 'moments.caps': 'and even Caps Lock.',
    'stages.title': 'Ready in a minute.',
    'stages.a.time': '10 seconds', 'stages.b.time': 'One minute', 'stages.c.time': 'All day',
    'stages.a.text': 'First, download the .dmg and drag Isla to Applications.',
    'stages.b.text': 'Then the welcome tour lets you turn on only the permissions you want.',
    'stages.c.text': 'After that, move the pointer to the notch or press ⌃⌥Space from any app.',
    'native.title': 'Made the way Apple would.',
    'native.text': 'Written in Swift and SwiftUI with macOS Liquid Glass, SF Symbols, haptic feedback and Settings that feel at home. Choose glass or classic black, the panel size, the tabs and the widgets. In English and Spanish.',
    'open.title': 'Open, like the sea.',
    'open.text': 'Isla is free and open source under the MIT License. No accounts, no analytics, no subscriptions. Your notes, Shelf and clipboard stay on your Mac. Read the code, suggest improvements or build your own.',
    'open.made': 'Designed and built by Kyros Solutions RD in Santo Domingo, on an island in the Caribbean. Hence the name.',
    'open.cta': 'View on GitHub',
    'faq.title': 'Questions, answered.',
    'faq.q1': 'Is Isla really free?', 'faq.a1': 'Yes. Every feature is free, forever, with no trial and no subscription. The code is on GitHub under the MIT License.',
    'faq.q2': 'Which Mac do I need?', 'faq.a2': 'Any Mac running macOS 26 Tahoe or later. Isla uses the system Liquid Glass, which is why it requires Tahoe. It runs on Apple silicon and Intel Macs.',
    'faq.q3': 'What if my Mac has no notch?', 'faq.a3': 'Isla draws a matching island at the top of any display, external monitors included. You choose which displays show it.',
    'faq.q4': 'Which music apps does it work with?', 'faq.a4': 'Any app that appears in Control Center’s Now Playing: Music, Spotify, Podcasts, YouTube in the browser and more. Lyrics come from LRCLIB, an open database.',
    'faq.q5': 'What permissions does it ask for, and what happens to my data?', 'faq.a5': 'Only the ones you turn on: Calendar, Reminders, Camera for the Mirror, Location for weather, Microphone for the teleprompter and Accessibility to replace the volume overlay. Nothing leaves your Mac except the weather lookup, with an approximate location, and the lyrics search.',
    'faq.q6': 'macOS says it can’t verify the app. What do I do?', 'faq.a6': 'Community builds are signed without a paid certificate. Right-click Isla, choose Open and confirm. Or build it yourself from source in a couple of minutes.',
    'cta.line': 'Your notch awaits.', 'cta.button': 'Download',
    'cta.note': 'Free, no accounts. Open the .dmg, drag Isla to Applications and move the pointer to the notch.',
    'footer.line': 'Let’s build Isla together.', 'footer.cta': 'How to contribute', 'footer.issues': 'Report an issue', 'footer.releases': 'Releases',
    'footer.org': 'Kyros Solutions RD', 'footer.license': 'MIT License',
    'footer.trademark': 'Mac, macOS, AirPods and AirDrop are trademarks of Apple Inc. Isla is not affiliated with Apple.', 'footer.photos': 'Photos:',
  };

  const nodes = [...document.querySelectorAll('[data-i18n]')];
  const spanish = new Map(nodes.map((node) => [node, node.textContent]));
  const ariaNodes = [...document.querySelectorAll('[data-i18n-aria]')];
  const spanishAria = new Map(ariaNodes.map((node) => [node, node.getAttribute('aria-label')]));
  const toggle = document.querySelector('[data-lang-toggle]');

  function applyLanguage(lang) {
    document.documentElement.lang = lang;
    nodes.forEach((node) => {
      const key = node.dataset.i18n;
      node.textContent = lang === 'en' && en[key] ? en[key] : spanish.get(node);
    });
    ariaNodes.forEach((node) => {
      const key = node.dataset.i18nAria;
      node.setAttribute('aria-label', lang === 'en' && en[key] ? en[key] : spanishAria.get(node));
    });
    if (toggle) {
      toggle.textContent = lang === 'en' ? 'ES' : 'EN';
      toggle.setAttribute('aria-label', lang === 'en' ? 'Cambiar idioma a español' : 'Change language to English');
    }
    document.title = lang === 'en'
      ? 'Isla: your notch, now an island. Free and open source for macOS'
      : 'Isla: tu notch es una isla. Gratis y de código abierto para macOS';
  }

  const params = new URLSearchParams(location.search);
  let language = params.get('lang') || localStorage.getItem('isla-lang') || 'es';
  if (language !== 'en') language = 'es';
  applyLanguage(language);
  toggle?.addEventListener('click', () => {
    language = language === 'en' ? 'es' : 'en';
    localStorage.setItem('isla-lang', language);
    applyLanguage(language);
  });

  /* ---------- Hero reel: the frames pass through the sentence ---------- */

  const hero = document.querySelector('.hero');
  const track = document.querySelector('.reel-track');
  const reel = document.querySelector('.reel');
  const wide = window.matchMedia('(min-width: 961px)');

  function updateReel() {
    if (!hero || !track || !reel || reduceMotion || !wide.matches) return;
    const frames = track.children;
    if (!frames.length) return;
    const frameHeight = frames[0].getBoundingClientRect().height;
    const step = frameHeight + 24;
    const total = hero.offsetHeight - window.innerHeight;
    const progress = Math.min(1, Math.max(0, -hero.getBoundingClientRect().top / Math.max(1, total)));
    const position = progress * (frames.length - 1);
    const center = reel.clientHeight / 2 - frameHeight / 2;
    track.style.transform = `translate3d(0, ${center - position * step}px, 0)`;
  }

  let ticking = false;
  window.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { updateReel(); ticking = false; });
  }, { passive: true });
  window.addEventListener('resize', updateReel);
  window.addEventListener('load', updateReel);
  updateReel();

  /* ---------- Live notch demo ---------- */

  const screen = document.querySelector('[data-screen]');
  if (screen) {
    const panel = screen.querySelector('[data-panel]');
    const panelImg = screen.querySelector('[data-panel-img]');
    const activityImg = screen.querySelector('[data-activity-img]');
    const tabs = ['home', 'shelf', 'clipboard', 'calendar', 'tasks', 'timers'];
    const more = ['notes', 'teleprompter'];
    let moreIndex = 0;
    let closeTimer;
    let activityTimer;

    const preload = (src) => { const image = new Image(); image.src = src; };
    [...tabs, ...more].forEach((tab) => preload(`assets/app/glass-${tab}.jpg`));
    ['airpods', 'charging', 'volume', 'meeting', 'download', 'track', 'caps', 'media'].forEach((name) => preload(`assets/app/act-${name}.jpg`));

    const pressed = (button) => {
      document.querySelectorAll('.try').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
    };

    function open(tab = 'home') {
      clearTimeout(closeTimer);
      endActivity();
      panelImg.src = `assets/app/glass-${tab}.jpg`;
      screen.dataset.state = 'open';
    }

    function close() {
      screen.dataset.state = 'closed';
      pressed(null);
    }

    function endActivity() {
      clearTimeout(activityTimer);
      delete screen.dataset.activityOn;
    }

    function showActivity(name, persistent = false) {
      close();
      const isTrack = name === 'track';
      activityImg.src = `assets/app/act-${name}.jpg`;
      activityImg.width = 1280;
      activityImg.height = isTrack ? 200 : 160;
      screen.dataset.activityOn = '';
      clearTimeout(activityTimer);
      if (!persistent) {
        activityTimer = setTimeout(() => showActivity('media', true), name === 'meeting' ? 5200 : 3200);
      }
    }

    // Music is playing in the captured session, so the island starts with it.
    showActivity('media', true);

    screen.querySelector('[data-open]').addEventListener('click', () => open('home'));
    screen.querySelector('.notch-hit').addEventListener('mouseenter', () => {
      if (window.matchMedia('(hover: hover)').matches) open('home');
    });
    screen.querySelector('.activity').addEventListener('click', () => open('home'));
    screen.addEventListener('mouseleave', () => {
      if (screen.dataset.state !== 'open') return;
      closeTimer = setTimeout(() => { close(); showActivity('media', true); }, 650);
    });
    screen.addEventListener('mouseenter', () => clearTimeout(closeTimer));

    panel.querySelectorAll('[data-tab]').forEach((button) => {
      button.addEventListener('click', (event) => {
        event.stopPropagation();
        let tab = button.dataset.tab;
        if (tab === 'more') { tab = more[moreIndex % more.length]; moreIndex += 1; }
        panelImg.src = `assets/app/glass-${tab}.jpg`;
      });
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && screen.dataset.state === 'open') { close(); showActivity('media', true); }
    });

    document.querySelectorAll('.try').forEach((button) => {
      button.addEventListener('click', () => {
        pressed(button);
        if (button.dataset.show) {
          open(button.dataset.show);
        } else {
          showActivity(button.dataset.act);
          setTimeout(() => button.setAttribute('aria-pressed', 'false'), 3200);
        }
      });
    });
  }

  /* ---------- Moments: one live activity lit at a time ---------- */

  const moments = [...document.querySelectorAll('[data-moment]')];
  const momentImg = document.querySelector('[data-moment-img]');
  if (moments.length && momentImg) {
    let index = 0;
    const light = () => {
      moments.forEach((moment, i) => moment.classList.toggle('is-lit', i === index));
      const name = moments[index].dataset.moment;
      momentImg.style.opacity = '0.0';
      setTimeout(() => {
        momentImg.src = `assets/app/act-${name}.jpg`;
        momentImg.width = 1280;
        momentImg.height = name === 'track' ? 200 : 160;
        momentImg.style.opacity = '1';
      }, reduceMotion ? 0 : 180);
      index = (index + 1) % moments.length;
    };
    light();
    if (!reduceMotion) setInterval(light, 2200);
  }

  /* ---------- Entrances ---------- */

  const groups = [
    ['.showcase', ['.head', '.section-lead', '.screen', '.try-actions']],
    ['.features-intro', ['.head']],
    ['.row', ['.row-title', '.row-text p', '.row-media']],
    ['.moments', ['.moments-sentence', '.moments-figure']],
    ['.stages', ['.head', '.bar-diagram', '.stage-notes']],
    ['.native', ['.head', '.native-text p', '.native-shot']],
    ['.open', ['.open-strip', '.head', '.open-text p', '.open-text .button', 'pre', '.open-photo']],
    ['.faq', ['.head', 'details']],
    ['.cta', ['.cta-line', '.cta-note']],
    ['.footer', ['.footer-line', '.footer-invite .button', '.footer-links li']],
  ];

  if (!reduceMotion && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.querySelectorAll('.reveal').forEach((node) => node.classList.add('in'));
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -12% 0px' });

    groups.forEach(([sectionSelector, parts]) => {
      document.querySelectorAll(sectionSelector).forEach((section) => {
        let i = 0;
        parts.forEach((selector) => {
          section.querySelectorAll(selector).forEach((node) => {
            node.classList.add('reveal');
            node.style.setProperty('--i', String(i++));
          });
        });
        observer.observe(section);
      });
    });
  }
})();
