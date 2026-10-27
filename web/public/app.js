const nav = document.querySelector(".nav");
const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 20);
onScroll();
addEventListener("scroll", onScroll, { passive: true });
const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

// Zoom demos. Each .cam has keyframes "t,x,y,zoom|..." where x,y is the point (in the
// app's 1120x740 window) the camera centers on. Videos loop their [start, end] stretch;
// images loop every data-loop seconds.
const ease = (p) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);

function camAt(keys, t) {
  if (t <= keys[0].t) return keys[0];
  for (let i = 1; i < keys.length; i++) {
    const a = keys[i - 1], b = keys[i];
    if (t <= b.t) {
      const p = ease((t - a.t) / (b.t - a.t));
      return { x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p, z: a.z + (b.z - a.z) * p };
    }
  }
  return keys[keys.length - 1];
}

const demos = [...document.querySelectorAll(".zframe")].map((frame) => {
  const cam = frame.querySelector(".cam");
  const keys = cam.dataset.cam.split("|").map((k) => {
    const [t, x, y, z] = k.split(",").map(Number);
    return { t, x, y, z };
  });
  const video = cam.querySelector("video");
  const img = cam.querySelector("img");
  return { frame, cam, keys, video, img, visible: false, began: performance.now() };
});

function place(d, t) {
  const W = d.frame.clientWidth, H = d.frame.clientHeight, base = W / 1120;
  const { x, y, z } = reduce ? d.keys[0] : camAt(d.keys, t);
  const s = base * z;
  // Center the focus point, but never show past the edge of the footage.
  const tx = Math.min(0, Math.max(W - 1120 * s, W / 2 - x * s));
  const ty = Math.min(0, Math.max(H - 740 * s, H / 2 - y * s));
  d.cam.style.transform = `translate(${tx}px, ${ty}px) scale(${s})`;
}

function tick(now) {
  for (const d of demos) {
    if (!d.visible) continue;
    if (d.video) {
      const start = +d.video.dataset.start, end = +d.video.dataset.end;
      if (d.video.currentTime < start || d.video.currentTime >= end) d.video.currentTime = start;
      place(d, d.video.currentTime - start);
    } else {
      const loop = +d.img.dataset.loop;
      place(d, ((now - d.began) / 1000) % loop);
    }
  }
  requestAnimationFrame(tick);
}
demos.forEach((d) => place(d, 0));
requestAnimationFrame(tick);
addEventListener("resize", () => demos.forEach((d) => place(d, 0)));

const seen = new IntersectionObserver((entries) => {
  for (const e of entries) {
    const d = demos.find((x) => x.frame === e.target);
    d.visible = e.isIntersecting;
    if (d.video) {
      if (e.isIntersecting) {
        d.video.currentTime = +d.video.dataset.start;
        d.video.play().catch(() => {});
      } else d.video.pause();
    } else if (e.isIntersecting) d.began = performance.now();
  }
}, { threshold: 0.35 });
demos.forEach((d) => seen.observe(d.frame));

// Corner Nimbus changes mood with the section you're looking at.
const buddy = document.querySelector(".buddy");
const setMood = (m) => { buddy.className = "buddy " + m; };
setMood("happy");
const moods = new IntersectionObserver((entries) => {
  for (const e of entries) if (e.isIntersecting) setMood(e.target.dataset.mood || "idle");
}, { rootMargin: "-45% 0px -45% 0px" });
document.querySelectorAll("[data-mood]").forEach((el) => moods.observe(el));
document.querySelector(".hero").dataset.mood = "happy";
document.querySelector(".tiles").dataset.mood = "idle";
document.querySelector(".final").dataset.mood = "happy";
document.querySelectorAll(".hero, .tiles, .final").forEach((el) => moods.observe(el));

// Tiles fade up as they come into view.
const rise = new IntersectionObserver((entries) => {
  for (const e of entries) if (e.isIntersecting) {
    e.target.animate([{ opacity: 0, transform: "translateY(24px)" }, { opacity: 1, transform: "none" }],
      { duration: 700, easing: "cubic-bezier(.2,.7,.2,1)", fill: "forwards" });
    rise.unobserve(e.target);
  }
}, { threshold: 0.15 });
document.querySelectorAll(".reveal").forEach((el) => rise.observe(el));
