const nav = document.querySelector(".nav");
const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 20);
onScroll();
addEventListener("scroll", onScroll, { passive: true });

// The demo stage is drawn at 1200x700 and scaled to fit the screen frame.
const screenEl = document.querySelector(".screen");
const cameraEl = document.querySelector(".camera");
const fit = () => { cameraEl.style.transform = `scale(${screenEl.clientWidth / 1200})`; };
fit();
new ResizeObserver(fit).observe(screenEl);

gsap.registerPlugin(ScrollTrigger);
const mm = gsap.matchMedia();

// Where the "camera" looks: a point on the 1200x700 stage and how far to zoom in.
const shots = {
  wide: { x: 600, y: 350, z: 1 },
  live: { x: 420, y: 640, z: 1.9 },
  notes: { x: 420, y: 330, z: 1.55 },
  answer: { x: 990, y: 470, z: 1.85 },
};

function cameraTo({ x, y, z }) {
  // Keep the focus point centered, and never show past the edge of the stage.
  const tx = Math.min(0, Math.max(1200 - 1200 * z, 600 - x * z));
  const ty = Math.min(0, Math.max(700 - 700 * z, 350 - y * z));
  return { x: tx, y: ty, scale: z };
}

mm.add("(prefers-reduced-motion: no-preference)", () => {
  gsap.set(".live p, .note, .thought", { autoAlpha: 0 });

  const tl = gsap.timeline({
    defaults: { ease: "power2.inOut" },
    scrollTrigger: { trigger: ".demo", start: "top top", end: "+=3600", pin: ".demo-pin", scrub: 0.8 },
  });

  const caption = (n) => {
    tl.to(".cap", { autoAlpha: 0, y: -12, duration: 0.3 }, "<");
    tl.fromTo(`.c${n}`, { autoAlpha: 0, y: 14 }, { autoAlpha: 1, y: 0, duration: 0.4 }, "<0.15");
  };

  tl.to({}, { duration: 0.4 })
    .to(".stage", { ...cameraTo(shots.live), duration: 1 }, "live");
  caption(1);
  tl.to(".live p", { autoAlpha: 1, stagger: 0.35, duration: 0.3 })
    .to(".stage", { ...cameraTo(shots.notes), duration: 1 }, "notes");
  caption(2);
  tl.to(".note", { autoAlpha: 1, y: 0, stagger: 0.3, duration: 0.35 }, ">-0.2")
    .to(".stage", { ...cameraTo(shots.answer), duration: 1 }, "answer");
  caption(3);
  tl.fromTo(".thought", { autoAlpha: 0, scale: 0.6 }, { autoAlpha: 1, scale: 1, duration: 0.5, ease: "back.out(1.6)" })
    .to({}, { duration: 0.5 })
    .to(".stage", { ...cameraTo(shots.wide), duration: 1 }, "wide");
  caption(4);
  tl.to({}, { duration: 0.6 });

  ScrollTrigger.batch(".reveal", {
    start: "top 85%",
    onEnter: (els) => gsap.to(els, { autoAlpha: 1, y: 0, stagger: 0.12, duration: 0.7, ease: "power3.out" }),
  });
});

mm.add("(prefers-reduced-motion: reduce)", () => {
  gsap.set(".cap", { autoAlpha: 0 });
  gsap.set(".c4", { autoAlpha: 1 });
});
