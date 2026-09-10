/* T2Do marketing site — interactions. Vanilla JS, no dependencies. */
(() => {
  const isStatic = location.search.includes('static');
  if (isStatic) document.documentElement.classList.add('static');
  const reduceMotion = isStatic || window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  /* ---------- headline word stagger ---------- */
  $$('.headline .word').forEach((w, i) => w.style.setProperty('--i', i));

  /* ---------- scroll reveal ---------- */
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add('in-view'); io.unobserve(e.target); }
    });
  }, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
  $$('.reveal, .reveal-scale').forEach((el) => isStatic ? el.classList.add('in-view') : io.observe(el));

  /* ---------- nav: scrolled state, hide on scroll down, active link ---------- */
  const nav = $('#nav');
  const progress = document.documentElement;
  let lastY = 0;
  const sections = $$('main section[id]');
  const links = $$('.nav-links a');
  const onScroll = () => {
    const y = window.scrollY;
    nav.classList.toggle('scrolled', y > 24);
    nav.classList.toggle('hidden', y > lastY && y > 400);
    lastY = y;
    const max = document.documentElement.scrollHeight - innerHeight;
    progress.style.setProperty('--progress', (y / max).toFixed(4));
    let current = '';
    sections.forEach((s) => { if (s.getBoundingClientRect().top < innerHeight * 0.45) current = s.id; });
    links.forEach((a) => a.classList.toggle('active', a.getAttribute('href') === `#${current}`));
  };
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---------- cursor glow + magnetic buttons + card spotlight ---------- */
  if (!reduceMotion && matchMedia('(pointer:fine)').matches) {
    const glow = $('.cursor-glow');
    addEventListener('pointermove', (e) => {
      glow.style.setProperty('--mx', `${e.clientX}px`);
      glow.style.setProperty('--my', `${e.clientY}px`);
    }, { passive: true });

    $$('.magnetic').forEach((btn) => {
      btn.addEventListener('pointermove', (e) => {
        const r = btn.getBoundingClientRect();
        const dx = (e.clientX - (r.left + r.width / 2)) / r.width;
        const dy = (e.clientY - (r.top + r.height / 2)) / r.height;
        btn.style.transform = `translate(${dx * 10}px, ${dy * 10}px) scale(1.03)`;
      });
      btn.addEventListener('pointerleave', () => { btn.style.transform = ''; });
    });

    $$('.feature').forEach((card) => {
      card.addEventListener('pointermove', (e) => {
        const r = card.getBoundingClientRect();
        const x = e.clientX - r.left, y = e.clientY - r.top;
        card.style.setProperty('--x', `${x}px`);
        card.style.setProperty('--y', `${y}px`);
        const rx = ((y / r.height) - 0.5) * -8, ry = ((x / r.width) - 0.5) * 8;
        card.style.transform = `perspective(900px) rotateX(${rx}deg) rotateY(${ry}deg) translateY(-4px)`;
      });
      card.addEventListener('pointerleave', () => { card.style.transform = ''; });
    });

    /* phone follows the pointer around the hero */
    const device = $('.hero-device');
    const phone = $('.phone');
    const hero = $('#hero');
    hero.addEventListener('pointermove', (e) => {
      const r = hero.getBoundingClientRect();
      const nx = (e.clientX - r.left) / r.width - 0.5;
      const ny = (e.clientY - r.top) / r.height - 0.5;
      phone.style.setProperty('--ry', `${-8 + nx * 18}deg`);
      phone.style.setProperty('--rx', `${4 - ny * 14}deg`);
    });
    hero.addEventListener('pointerleave', () => { phone.style.removeProperty('--ry'); phone.style.removeProperty('--rx'); });
    void device;
  }

  /* ---------- hero: count-up ---------- */
  $$('[data-count]').forEach((el) => {
    const target = +el.dataset.count;
    if (reduceMotion) { el.textContent = target; return; }
    const start = performance.now();
    const dur = 1400;
    const tick = (t) => {
      const p = Math.min(1, (t - start - 900) / dur);
      if (p >= 0) el.textContent = Math.round(target * (1 - Math.pow(1 - p, 3)));
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });

  /* ---------- hero phone: the strip needle creeps, tasks get done on a loop ---------- */
  const stripNeedle = $('#stripNeedle');
  if (stripNeedle && !reduceMotion) {
    let pos = 41;
    setInterval(() => { pos = pos > 66 ? 41 : pos + 0.03; stripNeedle.style.left = `${pos}%`; }, 100);
  }
  const heroLoop = () => {
    const first = $('#heroTasks .task:not(.gone)');
    const overdueCount = $('#heroTasks').previousElementSibling.querySelector('.count');
    if (!first) {
      // reset after a beat
      setTimeout(() => {
        $$('#heroTasks .task').forEach((t) => t.classList.remove('done', 'gone'));
        overdueCount.textContent = '3';
        setTimeout(heroLoop, 1800);
      }, 2200);
      return;
    }
    first.classList.add('done');
    setTimeout(() => {
      first.classList.add('gone');
      overdueCount.textContent = String(+overdueCount.textContent - 1);
      overdueCount.classList.remove('bump'); void overdueCount.offsetWidth; overdueCount.classList.add('bump');
      setTimeout(heroLoop, 2600);
    }, 700);
  };
  if (!reduceMotion) setTimeout(heroLoop, 3200);

  /* ---------- overdue demo: click to complete ---------- */
  const demo = $('#overdueDemo');
  const demoCount = $('#overdueCount');
  const demoCard = $('.overdue-card');
  const demoHTML = demo.innerHTML;
  const updateDemoCount = () => {
    const left = $$('.task:not(.gone)', demo).length;
    demoCount.textContent = left;
    demoCount.classList.remove('bump'); void demoCount.offsetWidth; demoCount.classList.add('bump');
    if (left === 0 && !$('.empty', demoCard)) {
      const empty = document.createElement('div');
      empty.className = 'empty';
      empty.innerHTML = '<strong>🎉</strong>Nothing overdue. Enjoy the quiet.';
      demo.after(empty);
    }
  };
  demo.addEventListener('click', (e) => {
    const task = e.target.closest('.task');
    if (!task || task.classList.contains('done')) return;
    task.classList.add('done');
    setTimeout(() => { task.classList.add('gone'); updateDemoCount(); }, 550);
  });
  $('#overdueReplay').addEventListener('click', () => {
    $('.empty', demoCard)?.remove();
    demo.innerHTML = demoHTML;
    demoCount.textContent = '3';
  });

  /* ---------- schedule: scrub the needle ---------- */
  const scrub = $('#scrub');
  const needle = $('#needle');
  const needleTime = $('#needleTime');
  const blocks = $$('#lanes .block');
  const freePill = $('#freePill');
  const START_HOUR = 9;
  const fmt = (h) => {
    const hh = Math.floor(h), mm = Math.round((h - hh) * 60);
    const ampm = hh >= 12 ? 'PM' : 'AM';
    const h12 = ((hh + 11) % 12) + 1;
    return `${h12}:${String(mm).padStart(2, '0')} ${ampm}`;
  };
  const setTime = (t) => {
    const rel = t - START_HOUR;
    needle.style.top = `calc(${rel} * var(--hour))`;
    needleTime.textContent = fmt(t);
    let nextStart = Infinity;
    blocks.forEach((b) => {
      const s = START_HOUR + parseFloat(b.style.getPropertyValue('--start'));
      const len = parseFloat(b.style.getPropertyValue('--len'));
      const end = s + len;
      b.classList.toggle('past', end <= t);
      b.classList.toggle('now', s <= t && t < end);
      if (s > t) nextStart = Math.min(nextStart, s);
    });
    const inBlock = blocks.some((b) => b.classList.contains('now'));
    let label;
    if (inBlock) label = 'In a block';
    else if (nextStart === Infinity) label = 'Free for the rest of the day';
    else {
      const mins = Math.round((nextStart - t) * 60);
      label = mins >= 60 ? `${(mins / 60).toFixed(mins % 60 ? 1 : 0)} hours free` : `${mins} min free`;
    }
    if (freePill.textContent !== label) {
      freePill.textContent = label;
      freePill.classList.remove('bump'); void freePill.offsetWidth; freePill.classList.add('bump');
    }
  };
  scrub.addEventListener('input', () => setTime(+scrub.value));
  setTime(+scrub.value);
  // gentle auto-advance until the user touches it
  if (!reduceMotion) {
    let touched = false;
    scrub.addEventListener('pointerdown', () => { touched = true; }, { once: true });
    const auto = setInterval(() => {
      if (touched) return clearInterval(auto);
      let v = +scrub.value + 0.01;
      if (v > 18) v = 8;
      scrub.value = v;
      setTime(v);
    }, 60);
  }

  /* ---------- light/dark compare slider ---------- */
  const compare = $('#compare');
  const handle = $('#compareHandle');
  const setSplit = (pct) => {
    pct = Math.max(2, Math.min(98, pct));
    compare.style.setProperty('--split', `${pct}%`);
    handle.setAttribute('aria-valuenow', Math.round(pct));
  };
  let dragging = false;
  const fromEvent = (e) => {
    const r = compare.getBoundingClientRect();
    setSplit(((e.clientX - r.left) / r.width) * 100);
  };
  compare.addEventListener('pointerdown', (e) => { dragging = true; fromEvent(e); });
  addEventListener('pointermove', (e) => { if (dragging) fromEvent(e); });
  addEventListener('pointerup', () => { dragging = false; });
  handle.addEventListener('keydown', (e) => {
    const cur = parseFloat(compare.style.getPropertyValue('--split')) || 50;
    if (e.key === 'ArrowLeft') setSplit(cur - 4);
    if (e.key === 'ArrowRight') setSplit(cur + 4);
  });
  // wiggle once when it scrolls into view so people know it moves
  if (!reduceMotion) {
    const wiggle = new IntersectionObserver((entries) => {
      if (!entries[0].isIntersecting) return;
      wiggle.disconnect();
      let t0 = null;
      const anim = (t) => {
        if (!t0) t0 = t;
        const p = (t - t0) / 1800;
        if (p >= 1 || dragging) { if (!dragging) setSplit(50); return; }
        setSplit(50 + Math.sin(p * Math.PI * 2) * 14 * (1 - p));
        requestAnimationFrame(anim);
      };
      setTimeout(() => requestAnimationFrame(anim), 500);
    }, { threshold: 0.5 });
    wiggle.observe(compare);
  }

  /* ---------- parallax on aurora blobs ---------- */
  if (!reduceMotion) {
    const blobs = $$('.blob');
    addEventListener('scroll', () => {
      const y = window.scrollY;
      blobs.forEach((b, i) => { b.style.translate = `0 ${y * (0.08 + i * 0.05)}px`; });
    }, { passive: true });
  }
})();
