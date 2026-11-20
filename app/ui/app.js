(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var state = { lang: "fr", theme: "system", textSize: 100, version: "", history: [], current: null, seq: 0 };
  var T = function () { return window.I18N[state.lang]; };

  // ---------------------------------------------------------------- bridge
  var host = window.chrome && window.chrome.webview;
  function send(msg) { if (host) host.postMessage(msg); else mock(msg); }
  if (host) host.addEventListener("message", function (e) { receive(e.data); });

  // Preview outside the app (plain browser): fake answers so the UI can be looked at.
  function mock(msg) {
    var sample = { score: 74, counts: { red: 0, yellow: 3, green: 8 }, areas: [
      { id: "stability", label: state.lang === "fr" ? "Stabilité" : "Stability", level: "green", findings: [] },
      { id: "storageSpace", label: state.lang === "fr" ? "Espace disque" : "Disk space", level: "yellow", findings: [{ level: "yellow", text: state.lang === "fr" ? "Peu d'espace sur le disque système : 40 Go libres (9 %)" : "Low space on the system disk: 40 GB free (9%)" }] },
      { id: "battery", label: state.lang === "fr" ? "Batterie" : "Battery", level: "skipped", findings: [] }
    ] };
    setTimeout(function () {
      if (msg.type === "init") receive({ type: "init", version: "preview", settings: { lang: state.lang, theme: state.theme, textSize: state.textSize }, history: [{ path: "demo", name: "20261121-101500" }] });
      if (msg.type === "runCheck") setTimeout(function () { receive({ type: "checkDone", path: "demo" }); }, 4000);
      if (msg.type === "score") receive({ type: "score", id: msg.id, path: msg.path, data: sample });
    }, 150);
  }

  function receive(m) {
    switch (m.type) {
      case "init":
        state.version = m.version;
        applySettings(m.settings, false);
        state.history = m.history || [];
        renderHome();
        break;
      case "checkDone":
        state.history.unshift({ path: m.path, name: fileName(m.path) });
        requestScore(m.path, "result");
        break;
      case "score":
        if (m.id === "last") renderLast(m);
        else if (m.id === "result" + state.seq) { showResults(m); }
        break;
      case "error":
        if (m.id === "last") { $("last-card").hidden = true; break; }
        showError(m.message);
        break;
    }
  }

  function requestScore(path, kind) {
    var id = kind === "result" ? "result" + (++state.seq) : kind;
    send({ type: "score", path: path, id: id });
  }

  // ---------------------------------------------------------------- settings
  function systemDark() { return window.matchMedia("(prefers-color-scheme: dark)").matches; }
  function effectiveDark() { return state.theme === "dark" || (state.theme === "system" && systemDark()); }

  function applySettings(s, save) {
    if (s) { state.lang = s.lang || state.lang; state.theme = s.theme || state.theme; state.textSize = +s.textSize || state.textSize; }
    var root = document.documentElement;
    root.lang = state.lang;
    root.dataset.theme = state.theme;
    root.style.fontSize = state.textSize + "%";
    translate();
    if (save) send({ type: "saveSettings", lang: state.lang, theme: state.theme, textSize: state.textSize, dark: effectiveDark() });
  }

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
    if (state.theme === "system") send({ type: "saveSettings", dark: effectiveDark() });
  });

  function translate() {
    var t = T();
    document.querySelectorAll("[data-i18n]").forEach(function (el) { var v = t[el.dataset.i18n]; if (typeof v === "string") el.textContent = v; });
    document.querySelectorAll("[data-i18n-aria]").forEach(function (el) { el.setAttribute("aria-label", t[el.dataset.i18nAria]); el.title = t[el.dataset.i18nAria]; });
    document.querySelectorAll("[data-lang]").forEach(function (b) { b.setAttribute("aria-pressed", b.dataset.lang === state.lang); });
    $("version").textContent = state.version ? "v" + state.version : "";
  }

  // ---------------------------------------------------------------- screens
  function show(name) {
    ["home", "running", "results", "error"].forEach(function (n) { $("screen-" + n).hidden = n !== name; });
    window.scrollTo(0, 0);
  }

  function fileName(p) { return String(p).split(/[\\/]/).pop().replace(/\.json$/i, ""); }
  function parseStamp(name) { // yyyyMMdd-HHmmss
    var m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/.exec(name || "");
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]) : null;
  }
  function formatDate(name) {
    var d = parseStamp(name);
    if (!d) return name || "";
    return d.toLocaleDateString(state.lang === "fr" ? "fr-FR" : "en-GB", { day: "numeric", month: "long", year: "numeric" }) +
      " · " + d.toLocaleTimeString(state.lang === "fr" ? "fr-FR" : "en-GB", { hour: "2-digit", minute: "2-digit" });
  }

  function renderHome() {
    var has = state.history.length > 0;
    $("first-steps").hidden = has;
    $("last-card").hidden = !has;
    if (has) {
      $("last-date").textContent = formatDate(state.history[0].name);
      $("last-status").textContent = T().scoring;
      $("last-ring").innerHTML = ringSvg(null, 64);
      requestScore(state.history[0].path, "last");
    }
    show("home");
  }

  function renderLast(m) {
    var d = m.data;
    $("last-ring").innerHTML = ringSvg(d.score, 64);
    $("last-status").textContent = titleFor(d);
    $("btn-last").onclick = function () { state.seq++; showResults({ path: m.path, data: d }); };
  }

  function titleFor(d) {
    var t = T(), c = d.counts || {};
    if (!c.red && !c.yellow) return t.titleGood;
    if (d.score >= 80) return t.titleOk;
    if (d.score >= 50) return t.titleWatch;
    return t.titleBad;
  }

  function levelOf(score) { return score >= 80 ? "green" : score >= 50 ? "yellow" : "red"; }

  function ringSvg(score, size) {
    var r = 42, c = 2 * Math.PI * r;
    var pct = score == null ? 0 : Math.max(0, Math.min(100, score)) / 100;
    var lvl = score == null ? "none" : levelOf(score);
    return '<svg viewBox="0 0 100 100" width="' + size + '" height="' + size + '" role="img" aria-label="' + (score == null ? "" : score + "/100") + '">' +
      '<circle class="ring-bg" cx="50" cy="50" r="' + r + '"/>' +
      '<circle class="ring-fg lvl-' + lvl + '" cx="50" cy="50" r="' + r + '" stroke-dasharray="' + c.toFixed(1) + '" stroke-dashoffset="' + (c * (1 - pct)).toFixed(1) + '" style="--full:' + c.toFixed(1) + '"/>' +
      '<text x="50" y="' + (size > 80 ? 52 : 50) + '" class="ring-num">' + (score == null ? "…" : score) + '</text>' +
      (size > 80 ? '<text x="50" y="70" class="ring-max">/100</text>' : "") + '</svg>';
  }

  var icons = {
    green: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    yellow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 7v6M12 17h.01"/></svg>',
    red: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 6v8M12 18h.01"/></svg>',
    skipped: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 12h10"/></svg>'
  };
  var order = { red: 0, yellow: 1, green: 2, skipped: 3 };

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (ch) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]; }); }

  function showResults(m) {
    var d = m.data, t = T();
    state.current = m.path;
    $("result-ring").innerHTML = ringSvg(d.score, 132);
    $("result-title").textContent = titleFor(d);
    $("result-summary").textContent = t.summary(d.counts || { red: 0, yellow: 0, green: 0 });
    $("result-date").textContent = t.checkedOn(formatDate(fileName(m.path)));
    var areas = (d.areas || []).slice().sort(function (a, b) { return order[a.level] - order[b.level]; });
    $("areas").innerHTML = areas.map(function (a) {
      var f = (a.findings || []).map(function (x) { return "<li>" + esc(x.text) + "</li>"; }).join("");
      return '<article class="card area lvl-' + a.level + '">' +
        '<div class="area-head"><h3>' + esc(a.label) + '</h3>' +
        '<span class="badge lvl-' + a.level + '">' + icons[a.level] + esc(t.level[a.level]) + '</span></div>' +
        (f ? "<ul>" + f + "</ul>" : (a.level === "green" ? '<p class="muted">' + esc(t.allGood) + "</p>" : "")) +
        "</article>";
    }).join("");
    show("results");
  }

  function showError(msg) { $("error-detail").textContent = msg || ""; show("error"); }

  // ---------------------------------------------------------------- running
  var timer = null;
  function startCheck() {
    show("running");
    var t = T(), i = 0, start = Date.now();
    $("running-msg").textContent = t.msgs[0];
    $("progress-bar").style.width = "2%";
    clearInterval(timer);
    timer = setInterval(function () {
      var s = (Date.now() - start) / 1000;
      // Eases towards 95 % over about a minute; the real end jumps to the results.
      $("progress-bar").style.width = Math.min(95, 100 * (1 - Math.exp(-s / 22))).toFixed(1) + "%";
      if (Math.floor(s / 4) > i && i < T().msgs.length - 1) { i++; $("running-msg").textContent = T().msgs[i]; }
      if ($("screen-running").hidden) clearInterval(timer);
    }, 250);
    send({ type: "runCheck" });
  }

  // ---------------------------------------------------------------- events
  $("btn-run").addEventListener("click", startCheck);
  $("btn-again").addEventListener("click", startCheck);
  $("btn-home").addEventListener("click", renderHome);
  $("btn-error-home").addEventListener("click", renderHome);
  document.querySelectorAll("[data-lang]").forEach(function (b) {
    b.addEventListener("click", function () {
      if (state.lang === b.dataset.lang) return;
      state.lang = b.dataset.lang;
      applySettings(null, true);
      if (!$("screen-results").hidden && state.current) requestScore(state.current, "result");
      else if (!$("screen-home").hidden) renderHome();
    });
  });

  var dlg = $("settings");
  $("btn-settings").addEventListener("click", function () {
    dlg.querySelector('input[name=theme][value="' + state.theme + '"]').checked = true;
    dlg.querySelector('input[name=size][value="' + state.textSize + '"]').checked = true;
    dlg.showModal();
  });
  dlg.addEventListener("change", function (e) {
    if (e.target.name === "theme") state.theme = e.target.value;
    if (e.target.name === "size") state.textSize = +e.target.value;
    applySettings(null, true);
  });

  document.addEventListener("keydown", function (e) {
    if (dlg.open) return;
    if (e.key === "Enter" && !$("screen-home").hidden && document.activeElement === document.body) startCheck();
    if (e.key === "Escape" && ($("screen-results").hidden === false || $("screen-error").hidden === false)) renderHome();
  });

  translate();
  send({ type: "init" });
})();
