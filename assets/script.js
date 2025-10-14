/* Mobile nav toggle */
const toggle = document.querySelector('.nav__toggle');
const list = document.querySelector('.nav__list');
if (toggle && list) {
  toggle.addEventListener('click', () => {
    const open = list.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(open));
  });
}

/* Smooth scroll for in-page links */
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const id = a.getAttribute('href');
    if (!id || id === '#') return;
    const el = document.querySelector(id);
    if (!el) return;
    e.preventDefault();
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    list?.classList.remove('open');
    toggle?.setAttribute('aria-expanded', 'false');
  });
});

/* Year in footer */
const yearEl = document.getElementById('year');
if (yearEl) yearEl.textContent = String(new Date().getFullYear());