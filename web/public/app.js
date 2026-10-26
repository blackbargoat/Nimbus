// Nav gets a frosted background once you scroll.
const nav = document.querySelector(".nav");
const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 20);
onScroll();
window.addEventListener("scroll", onScroll, { passive: true });

// Cards fade up as they come into view.
const io = new IntersectionObserver(
  (entries) => entries.forEach((e) => e.isIntersecting && (e.target.classList.add("in"), io.unobserve(e.target))),
  { threshold: 0.15 }
);
document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

// The hero answer types itself out like Nimbus is answering live.
const typed = document.getElementById("typed");
const answer =
  "Say: Because about 20% of the world's oil goes through it, so if Iran closes it, gas prices go up everywhere, even for countries that aren't in the war.";
const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function render(text) {
  const [label, ...rest] = text.split(":");
  typed.innerHTML = text.includes(":") ? `<b>${label}:</b>${rest.join(":")}` : text;
}

if (reduce) {
  render(answer);
  typed.classList.add("done");
} else {
  let i = 0;
  setTimeout(function tick() {
    i += 1 + Math.floor(Math.random() * 2);
    render(answer.slice(0, i));
    if (i < answer.length) setTimeout(tick, 22 + Math.random() * 30);
    else typed.classList.add("done");
  }, 900);
}
