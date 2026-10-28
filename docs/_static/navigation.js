"use strict";

// Apply the saved appearance before the document is drawn.
try {
  const appearance = localStorage.getItem("docs-appearance");
  if (["light", "dark"].includes(appearance)) {
    document.documentElement.dataset.appearance = appearance;
  }
} catch (_) { /* Storage is optional. */ }

document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector(".navigation-toggle");
  const sidebar = document.querySelector(".symbol-sidebar");
  const filter = document.getElementById("symbol-filter");
  const groups = Array.from(document.querySelectorAll(".symbol-tree > ul"));

  function closeNavigation() {
    document.body.classList.remove("navigation-open");
    toggle.setAttribute("aria-expanded", "false");
    toggle.setAttribute("aria-label", "Show navigation");
  }

  toggle.addEventListener("click", () => {
    const open = document.body.classList.toggle("navigation-open");
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Hide navigation" : "Show navigation");
  });

  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && document.body.classList.contains("navigation-open")) {
      closeNavigation();
      toggle.focus();
    }
    if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey ||
        event.target.closest("input, textarea, select, [contenteditable]")) return;
    event.preventDefault();
    if (matchMedia("(max-width: 900px)").matches) {
      document.body.classList.add("navigation-open");
      toggle.setAttribute("aria-expanded", "true");
      toggle.setAttribute("aria-label", "Hide navigation");
    }
    filter.focus();
  });

  sidebar.addEventListener("click", event => {
    if (event.target.closest("a")) closeNavigation();
  });

  filter.addEventListener("input", () => {
    const query = filter.value.trim().toLowerCase();
    let matches = 0;
    for (const group of groups) {
      let groupMatches = 0;
      for (const item of group.children) {
        const visible = item.textContent.toLowerCase().includes(query);
        item.hidden = !visible;
        if (visible) groupMatches++;
      }
      group.hidden = groupMatches === 0;
      const caption = group.previousElementSibling;
      if (caption?.classList.contains("caption")) caption.hidden = groupMatches === 0;
      matches += groupMatches;
    }
    document.querySelector(".filter-empty").hidden = matches > 0;
  });

  const current = sidebar.querySelector("a.current");
  if (current) {
    current.setAttribute("aria-current", "page");
    current.scrollIntoView({block: "nearest"});
  }

  const appearance = document.getElementById("appearance");
  appearance.value = document.documentElement.dataset.appearance || "auto";
  appearance.addEventListener("change", () => {
    document.documentElement.dataset.appearance = appearance.value;
    try { localStorage.setItem("docs-appearance", appearance.value); } catch (_) {}
  });
});
