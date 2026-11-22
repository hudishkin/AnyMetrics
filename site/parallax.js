// Pointer parallax for the home page: the glow drifts against the cursor, the card follows it slightly.
(function () {
  var glow = document.querySelector(".glow");
  var card = document.querySelector(".lockup");
  if (!glow || !card) return;

  var media = window.matchMedia("(hover: hover) and (pointer: fine) and (prefers-reduced-motion: no-preference)");
  var target = { x: 0, y: 0 };
  var current = { x: 0, y: 0 };
  var frame = 0;

  function render() {
    current.x += (target.x - current.x) * 0.08;
    current.y += (target.y - current.y) * 0.08;
    glow.style.transform = "translate3d(" + (current.x * -32) + "px," + (current.y * -24) + "px,0)";
    card.style.transform = "translate3d(" + (current.x * 6) + "px," + (current.y * 5) + "px,0)";

    var settled = Math.abs(target.x - current.x) < 0.001 && Math.abs(target.y - current.y) < 0.001;
    frame = settled ? 0 : requestAnimationFrame(render);
  }

  function schedule() {
    if (!frame) frame = requestAnimationFrame(render);
  }

  function onMove(event) {
    target.x = event.clientX / window.innerWidth * 2 - 1;
    target.y = event.clientY / window.innerHeight * 2 - 1;
    schedule();
  }

  function onLeave() {
    target.x = 0;
    target.y = 0;
    schedule();
  }

  function sync() {
    if (media.matches) {
      window.addEventListener("pointermove", onMove);
      document.documentElement.addEventListener("mouseleave", onLeave);
    } else {
      window.removeEventListener("pointermove", onMove);
      document.documentElement.removeEventListener("mouseleave", onLeave);
      onLeave();
    }
  }

  sync();
  media.addEventListener("change", sync);
})();
