// Light/dark theme: follows the system until the user picks one with the toggle.
(function () {
  var root = document.documentElement;
  var system = window.matchMedia("(prefers-color-scheme: light)");
  var button = document.querySelector(".theme-toggle");
  var meta = document.querySelector('meta[name="theme-color"]');

  function stored() {
    try {
      return localStorage.getItem("theme");
    } catch (error) {
      return null;
    }
  }

  function apply(theme) {
    root.dataset.theme = theme;
    if (button) button.setAttribute("aria-checked", theme === "dark" ? "true" : "false");
    if (meta) meta.setAttribute("content", getComputedStyle(document.body).backgroundColor);
  }

  apply(stored() || (system.matches ? "light" : "dark"));

  system.addEventListener("change", function () {
    if (!stored()) apply(system.matches ? "light" : "dark");
  });

  if (button) {
    button.addEventListener("click", function () {
      var next = root.dataset.theme === "dark" ? "light" : "dark";
      try {
        localStorage.setItem("theme", next);
      } catch (error) {}
      apply(next);
    });
  }
})();
