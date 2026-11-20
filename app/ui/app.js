(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var state = {
    lang: "fr", theme: "system", textSize: 100, version: "",
    history: [],          // [{path, name}] newest first
    points: [],           // [{name, score}] oldest first
    current: null,        // {path, data} shown in results
    symptom: null,        // symptom chosen on the home screen for the next check
    resultSymptom: null,  // symptom the shown results were run for
    seq: 0, tech: false
  };
  var T = function () { return window.I18N[state.lang]; };

  // ---------------------------------------------------------------- bridge
  var host = window.chrome && window.chrome.webview;
  function send(msg) { if (host) host.postMessage(msg); else mock(msg); }
  if (host) host.addEventListener("message", function (e) { receive(e.data); });

  // Preview outside the app (plain browser): fake answers so the UI can be looked at.
  function mock(msg) {
    var fr = state.lang === "fr";
    var sample = { score: 74, counts: { red: 0, yellow: 3, green: 8 }, areas: [
      { id: "stability", label: fr ? "Stabilité" : "Stability", level: "green", findings: [] },
      { id: "storageSpace", label: fr ? "Espace disque" : "Disk space", level: "yellow", findings: [{ id: "space.system.low", level: "yellow", text: fr ? "Peu d'espace sur le disque système : 40 Go libres (9 %)" : "Low space on the system disk: 40 GB free (9%)" }] },
      { id: "hardwareErrors", label: fr ? "Matériel" : "Hardware", level: "yellow", findings: [{ id: "whea.some", level: "yellow", text: fr ? "2 erreur(s) matérielle(s) corrigée(s) (WHEA)" : "2 corrected hardware error(s) (WHEA)" }] },
      { id: "maintenance", label: fr ? "Entretien" : "Maintenance", level: "yellow", findings: [{ id: "maint.reboot.pending", level: "yellow", text: fr ? "Redémarrage en attente" : "Restart pending" }] },
      { id: "battery", label: fr ? "Batterie" : "Battery", level: "skipped", findings: [] }
    ], facts: { crashes30d: 0, systemFreePct: 9, systemFreeGB: 40, wheaCorrected: 2 } };
    var hist = [{ path: "demo2", name: "20261121-101500" }, { path: "demo1", name: "20261114-093000" }];
    setTimeout(function () {
      if (msg.type === "init") receive({ type: "init", version: "0.1.0", whatsNew: location.hash === "#updated", updatedAt: location.hash === "#updated" ? "2026-11-21T14:32:00" : null, updatedFrom: location.hash === "#updated" ? "0.0.9" : null, settings: { lang: state.lang, theme: state.theme, textSize: state.textSize }, history: hist });
      if (msg.type === "scores") receive({ type: "scores", points: [{ name: "20261101-120000", score: 46 }, { name: "20261107-120000", score: 58 }, { name: "20261114-093000", score: 66 }, { name: "20261121-101500", score: 74 }] });
      if (msg.type === "runCheck") setTimeout(function () { receive({ type: "checkDone", path: "demo2" }); }, 3000);
      if (msg.type === "score") receive({ type: "score", id: msg.id, path: msg.path, data: sample, admin: msg.path === "demo2" ? {
        smart: { available: true, devices: [{ model: "Contoso NVMe 1TB", smartPassed: true, temperatureC: 41, powerOnHours: 9120, nvme: { percentageUsed: 7, availableSparePct: 100, mediaErrors: 0, dataWrittenTB: 38.2 } }] },
        reliability: [], volumeScan: [{ drive: "C:", result: "NoErrorsFound" }],
        dumpAnalysis: { available: true, results: [{ date: "2026-11-17T12:14:00", bugcheckName: "DPC_WATCHDOG_VIOLATION", imageName: "example.sys" }] },
        bootPerformance: { lastBootSec: 38.4, avgBootSec: 41.2, stale: false, slowdowns: [{ key: "101 Example Updater", count: 3, avgDelaySec: 4.1 }] }
      } : null });
      if (msg.type === "runCheck" && msg.admin) { setTimeout(function () { receive({ type: "adminStart" }); }, 1000); setTimeout(function () { receive({ type: "adminRunning" }); }, 1800); }
      if (msg.type === "compare") receive({ type: "compare", id: msg.id, data: { comparable: true, daysBetween: 7, volumes: [{ drive: "C:", freeGB: 40, deltaFreeGB: 22.4 }], stability: { newUnexpectedShutdowns: 0, newBugchecks: [] }, newGpuEvents: [], newDiskEvents: [], newHardwareErrors: [{ count: 2 }] } });
      if (msg.type === "copy") receive({ type: "copied", ok: true });
      if (msg.type === "pdf") receive({ type: "pdf", ok: true });
      if (msg.type === "checkUpdate") receive({ type: "update", version: "0.2.0", notes: "- Exemple de note de version\n- Example release note" });
      if (msg.type === "doUpdate") { var p = 0, iv = setInterval(function () { p += 20; receive({ type: "updateProgress", pct: p }); if (p >= 100) clearInterval(iv); }, 200); }
    }, 150);
  }

  function receive(m) {
    switch (m.type) {
      case "init":
        state.version = m.version;
        state.noUpdateCheck = !!(m.settings && m.settings.noUpdateCheck);
        state.updatedAt = m.updatedAt || null;
        state.updatedFrom = m.updatedFrom || null;
        applySettings(m.settings, false);
        state.history = m.history || [];
        renderHome();
        send({ type: "scores" });
        if (m.whatsNew) showWhatsNew(true);
        break;
      case "update":
        $("update-title").textContent = T().updateAvailable(m.version);
        $("update-notes").textContent = m.notes || "";
        $("update-notes-box").hidden = !m.notes;
        $("update-progress").hidden = true;
        $("btn-update").disabled = false;
        $("update-banner").hidden = false;
        $("update-status").textContent = T().updateAvailable(m.version);
        state.newVersion = { version: m.version, notes: m.notes || "" };
        translate();
        break;
      case "upToDate": $("update-status").textContent = T().upToDate; break;
      case "updateProgress":
        $("update-progress").hidden = false;
        $("update-bar").style.width = m.pct + "%";
        break;
      case "updateFailed":
        $("update-status").textContent = T().updateFailed + m.message;
        if (m.install) {
          $("btn-update").disabled = false;
          $("update-progress").hidden = true;
          if (confirm(T().updateFailed + m.message + "\n\n" + T().updateManual)) send({ type: "open", target: "releases" });
        }
        break;
      case "scores":
        state.points = m.points || [];
        renderCurve();
        break;
      case "adminStart":
        runPhase = "ask";
        $("running-msg").textContent = T().adminAsk;
        break;
      case "adminRunning":
        runPhase = "admin"; phaseStart = Date.now();
        $("running-msg").textContent = T().adminMsgs[0];
        break;
      case "checkDone":
        adminStates[m.path] = m.admin || null;
        state.history = state.history.filter(function (h) { return h.path !== m.path; });
        state.history.unshift({ path: m.path, name: fileName(m.path) });
        state.resultSymptom = state.symptom;
        requestScore(m.path, "result");
        send({ type: "scores" });
        break;
      case "score":
        if (m.id === "last") renderLast(m);
        else if (m.id === "tech") renderTech(m.data);
        else if (m.id === "result" + state.seq) showResults(m);
        break;
      case "compare":
        if (m.id === "since") renderSince(m.data);
        else if (m.id === "dialog") renderCompareDialog(m.data);
        break;
      case "compareFailed":
        if (m.id === "since") $("since-block").hidden = true;
        else $("cmp-out").textContent = m.message;
        break;
      case "copied": toast(m.ok ? T().copied : T().copyFailed); break;
      case "pdf": endPrint(); toast(m.ok ? T().pdfDone : T().pdfFailed + (m.message || "")); break;
      case "openFailed": toast(T().openFailed + m.message); break;
      case "toolNoWinget": alert(T().toolNoWinget(m.tool)); break;
      case "error":
        if (m.id === "last") { $("last-card").hidden = true; break; }
        if (m.id === "tech") { $("tech-out").textContent = m.message; break; }
        showError(m.message);
        break;
    }
  }

  function requestScore(path, kind, full) {
    var id = kind === "result" ? "result" + (++state.seq) : kind;
    send({ type: "score", path: path, id: id, full: !!full });
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
    $("version").textContent = state.version ? "v" + state.version + (state.newVersion ? " · " + t.newVersionShort : "") : "";
    $("version").classList.toggle("has-update", !!state.newVersion);
    renderSymptoms();
  }

  // ---------------------------------------------------------------- helpers
  function show(name) {
    ["home", "running", "results", "error"].forEach(function (n) { $("screen-" + n).hidden = n !== name; });
    window.scrollTo(0, 0);
  }
  function fileName(p) { return String(p).split(/[\\/]/).pop().replace(/\.json$/i, ""); }
  function parseStamp(name) {
    var m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/.exec(name || "");
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]) : null;
  }
  function locale() { return state.lang === "fr" ? "fr-FR" : "en-GB"; }
  function formatDate(name, short) {
    var d = parseStamp(name);
    if (!d) return name || "";
    if (short) return d.toLocaleDateString(locale(), { day: "numeric", month: "short" });
    return d.toLocaleDateString(locale(), { day: "numeric", month: "long", year: "numeric" }) +
      " · " + d.toLocaleTimeString(locale(), { hour: "2-digit", minute: "2-digit" });
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (ch) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]; }); }
  function fmtNum(n) { return Number(n).toLocaleString(locale(), { maximumFractionDigits: 1 }); }

  var toastTimer = null;
  function toast(text) {
    var el = $("toast");
    el.textContent = text;
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { el.hidden = true; }, 3200);
  }

  // Glossary: technical words get an explanation on hover or keyboard focus. Input is escaped HTML.
  function gloss(html) {
    var g = window.GLOSSARY[state.lang];
    var terms = Object.keys(g).sort(function (a, b) { return b.length - a.length; });
    var re = new RegExp("(^|[^\\w\\u00C0-\\u017F/-])(" + terms.map(function (t) { return t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }).join("|") + ")(?![\\w\\u00C0-\\u017F])", "g");
    return html.replace(re, function (all, pre, term) {
      return pre + '<abbr class="gloss" tabindex="0" data-tip="' + esc(g[term]) + '">' + term + "</abbr>";
    });
  }

  // ---------------------------------------------------------------- home
  var SYMPTOMS = {
    bsod: ["stability", "hardwareErrors", "diskHealth", "heat"],
    black: ["graphics", "stability", "heat"],
    slow: ["performance", "storageSpace", "maintenance", "heat", "diskHealth", "bootTime"],
    reboot: ["stability", "hardwareErrors", "heat"],
    games: ["graphics", "stability", "heat", "performance"],
    disk: ["diskHealth", "storageSpace"],
    net: ["network"]
  };

  function renderSymptoms() {
    var t = T(), box = $("symptoms");
    if (!box) return;
    box.innerHTML = Object.keys(SYMPTOMS).map(function (k) {
      return '<button type="button" class="chip" data-symptom="' + k + '" aria-pressed="' + (state.symptom === k) + '">' + esc(t.symptoms[k]) + "</button>";
    }).join("");
  }

  $("symptoms").addEventListener("click", function (e) {
    var b = e.target.closest("[data-symptom]");
    if (!b) return;
    state.symptom = state.symptom === b.dataset.symptom ? null : b.dataset.symptom;
    renderSymptoms();
    $("btn-run").textContent = state.symptom ? T().runFor : T().run;
  });

  function renderHome() {
    var has = state.history.length > 0;
    $("first-steps").hidden = has;
    $("last-card").hidden = !has;
    $("btn-run").textContent = state.symptom ? T().runFor : T().run;
    if (has) {
      $("last-date").textContent = formatDate(state.history[0].name);
      $("last-status").textContent = T().scoring;
      $("last-ring").innerHTML = ringSvg(null, 64);
      requestScore(state.history[0].path, "last");
    }
    renderCurve();
    show("home");
  }

  function renderLast(m) {
    var d = m.data;
    $("last-ring").innerHTML = ringSvg(d.score, 64);
    $("last-status").textContent = titleFor(d);
    $("btn-last").onclick = function () { state.seq++; state.resultSymptom = null; showResults({ path: m.path, data: d, admin: m.admin }); };
  }

  // Score curve of the last checks (needs 2 points or more).
  function renderCurve() {
    var pts = state.points.slice(-10), card = $("curve-card");
    if (pts.length < 2 || !$("screen-home") || state.history.length === 0) { card.hidden = true; return; }
    card.hidden = false;
    var w = 560, h = 120, px = 28, py = 18;
    var x = function (i) { return px + i * (w - 2 * px) / (pts.length - 1); };
    var y = function (s) { return py + (100 - s) * (h - 2 * py) / 100; };
    var line = pts.map(function (p, i) { return (i ? "L" : "M") + x(i).toFixed(1) + " " + y(p.score).toFixed(1); }).join(" ");
    var dots = pts.map(function (p, i) {
      return '<g><circle class="curve-dot lvl-' + levelOf(p.score) + '" cx="' + x(i).toFixed(1) + '" cy="' + y(p.score).toFixed(1) + '" r="4.5"><title>' +
        esc(formatDate(p.name, true) + " · " + p.score + "/100") + "</title></circle>" +
        '<text class="curve-label" x="' + x(i).toFixed(1) + '" y="' + (y(p.score) - 10).toFixed(1) + '">' + p.score + "</text>" +
        '<text class="curve-date" x="' + x(i).toFixed(1) + '" y="' + (h - 2) + '">' + esc(formatDate(p.name, true)) + "</text></g>";
    }).join("");
    var first = pts[0].score, last = pts[pts.length - 1].score, diff = last - first;
    $("curve-trend").textContent = diff === 0 ? T().trendFlat : (diff > 0 ? "+" : "") + diff + " " + T().trendSince(formatDate(pts[0].name, true));
    $("curve-trend").className = "curve-trend " + (diff > 0 ? "up" : diff < 0 ? "down" : "");
    $("curve").innerHTML = '<svg viewBox="0 0 ' + w + " " + h + '" preserveAspectRatio="none" role="img" aria-label="' + esc(T().curveTitle) + '">' +
      '<line class="curve-grid" x1="' + px + '" x2="' + (w - px) + '" y1="' + y(80) + '" y2="' + y(80) + '"/>' +
      '<line class="curve-grid" x1="' + px + '" x2="' + (w - px) + '" y1="' + y(50) + '" y2="' + y(50) + '"/>' +
      '<path class="curve-line" d="' + line + '"/>' + dots + "</svg>";
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
      '<text x="50" y="' + (size > 80 ? 52 : 50) + '" class="ring-num">' + (score == null ? "…" : score) + "</text>" +
      (size > 80 ? '<text x="50" y="70" class="ring-max">/100</text>' : "") + "</svg>";
  }

  // ---------------------------------------------------------------- results
  var icons = {
    green: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    yellow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 7v6M12 17h.01"/></svg>',
    red: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 6v8M12 18h.01"/></svg>',
    skipped: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 12h10"/></svg>'
  };
  var order = { red: 0, yellow: 1, green: 2, skipped: 3 };

  function sortedAreas(d) {
    var focus = state.resultSymptom ? SYMPTOMS[state.resultSymptom] : [];
    return (d.areas || []).slice().sort(function (a, b) {
      var fa = focus.indexOf(a.id) >= 0 ? 0 : 1, fb = focus.indexOf(b.id) >= 0 ? 0 : 1;
      if (fa !== fb && (a.level !== "green" || b.level !== "green")) {
        // Symptom areas with a problem come first, then the usual severity order.
        var pa = fa === 0 && a.level !== "green" && a.level !== "skipped" ? 0 : 1;
        var pb = fb === 0 && b.level !== "green" && b.level !== "skipped" ? 0 : 1;
        if (pa !== pb) return pa - pb;
      }
      return order[a.level] - order[b.level];
    });
  }

  function showResults(m) {
    var d = m.data, t = T();
    state.current = { path: m.path, data: d };
    state.tech = false;
    $("tech-block").hidden = true;
    $("btn-tech").setAttribute("aria-pressed", "false");
    $("result-ring").innerHTML = ringSvg(d.score, 132);
    $("result-title").textContent = titleFor(d);
    $("result-summary").textContent = t.summary(d.counts || { red: 0, yellow: 0, green: 0 });
    $("result-date").textContent = t.checkedOn(formatDate(fileName(m.path)));

    var sym = state.resultSymptom;
    $("symptom-banner").hidden = !sym;
    if (sym) {
      var hit = (d.areas || []).filter(function (a) { return SYMPTOMS[sym].indexOf(a.id) >= 0 && (a.level === "red" || a.level === "yellow"); });
      $("symptom-banner").innerHTML = "<strong>" + esc(t.symptomFor(t.symptoms[sym])) + "</strong> " +
        esc(hit.length ? t.symptomHit(hit.map(function (a) { return a.label; }).join(", ")) : t.symptomNone);
    }

    var areas = sortedAreas(d);
    $("areas").innerHTML = areas.map(function (a) {
      var f = (a.findings || []).map(function (x) { return "<li>" + gloss(esc(x.text)) + "</li>"; }).join("");
      var focus = sym && SYMPTOMS[sym].indexOf(a.id) >= 0 ? " focus" : "";
      return '<article class="card area lvl-' + a.level + focus + '">' +
        '<div class="area-head"><h3>' + esc(a.label) + "</h3>" +
        '<span class="badge lvl-' + a.level + '">' + icons[a.level] + esc(t.level[a.level]) + "</span></div>" +
        (f ? "<ul>" + f + "</ul>" : (a.level === "green" ? '<p class="muted">' + esc(t.allGood) + "</p>" : "")) +
        "</article>";
    }).join("");
    var adviceIds = renderAdvice(areas);
    startSince(m.path, adviceIds);
    renderAdmin(m.admin, adminStates[m.path]);
    show("results");
  }

  // ---- deep scan (admin) section
  var adminStates = {}; // snapshot path -> "ok" | "declined" | "failed" (this session only)

  function renderAdmin(a, st) {
    var t = T(), out = [];
    if (!a) {
      $("admin-block").hidden = !(st === "declined" || st === "failed");
      $("admin-out").innerHTML = '<div class="card admin-card"><p>' + esc(st === "declined" ? t.deepDeclined : t.deepFailed) + "</p></div>";
      return;
    }
    $("admin-block").hidden = false;
    var tool = function (name, key) {
      return '<p class="muted">' + esc(t.toolMissing(name)) + '</p><button type="button" class="secondary small-btn" data-install="' + key + '">' +
        esc(t.toolInstall(name)) + "</button>";
    };
    var card = function (title, body) { return '<div class="card admin-card"><h3>' + esc(title) + "</h3>" + body + "</div>"; };

    // Disks: SMART when smartctl is there, Windows reliability counters otherwise.
    var disks = "";
    var sm = a.smart || {};
    if (sm.available && sm.devices && sm.devices.length) {
      disks = "<ul>" + sm.devices.map(function (d) {
        var bits = [], nv = d.nvme || {};
        bits.push(d.smartPassed === false ? '<span class="bad">' + esc(t.smartBad) + "</span>" : '<span class="good">' + esc(t.smartOk) + "</span>");
        if (nv.percentageUsed != null) bits.push(esc(t.wear(nv.percentageUsed)));
        if (nv.availableSparePct != null) bits.push(esc(t.spare(nv.availableSparePct)));
        if (nv.mediaErrors) bits.push('<span class="bad">' + esc(t.mediaErrors(nv.mediaErrors)) + "</span>");
        if (d.temperatureC != null) bits.push(esc(t.temp(d.temperatureC)));
        if (nv.dataWrittenTB != null) bits.push(esc(t.written(fmtNum(nv.dataWrittenTB))));
        if (d.powerOnHours != null) bits.push(esc(t.hours(d.powerOnHours)));
        return "<li><strong>" + esc(d.model || d.device) + "</strong><br>" + gloss(bits.join(" · ")) + "</li>";
      }).join("") + "</ul>";
    } else {
      var rel = a.reliability || [];
      disks = rel.length ? "<ul>" + rel.map(function (r) {
        var bits = [];
        if (r.wearPct != null) bits.push(esc(t.wear(r.wearPct)));
        if (r.temperatureC) bits.push(esc(t.temp(r.temperatureC)));
        if (r.readUncorrected) bits.push('<span class="bad">' + esc(t.mediaErrors(r.readUncorrected)) + "</span>");
        if (r.powerOnHours) bits.push(esc(t.hours(r.powerOnHours)));
        return "<li><strong>" + esc(r.name) + "</strong>" + (bits.length ? "<br>" + bits.join(" · ") : "") + "</li>";
      }).join("") + "</ul>" : "";
      if (sm.available === false) disks += tool("smartctl", "smartctl");
    }
    out.push(card(t.disksTitle, disks));

    // Blue screens (only when the option was on: the section exists then).
    if (a.dumpAnalysis) {
      var da = a.dumpAnalysis, body;
      if (da.available === false) body = tool("WinDbg", "windbg");
      else if (!da.results || !da.results.length) body = '<p class="muted">' + esc(t.noDumps) + "</p>";
      else body = "<ul>" + da.results.map(function (r) {
        var when = r.date ? new Date(r.date).toLocaleString(locale(), { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }) : r.file;
        var who = r.imageName || r.moduleName;
        return "<li><strong>" + esc(when) + "</strong> · " + esc(r.bugcheckName || r.bugcheckCode || "?") +
          (who ? '<br><span class="bad">' + esc(t.culprit(who)) + "</span>" : "") + "</li>";
      }).join("") + "</ul>";
      out.push(card(t.dumpsTitle, body));
    }

    // Startup.
    var bp = a.bootPerformance;
    if (bp && bp.lastBootSec != null) {
      var b = "<p>" + esc(t.bootLast(fmtNum(bp.lastBootSec), bp.avgBootSec != null ? fmtNum(bp.avgBootSec) : null)) + "</p>";
      if (bp.stale) b += '<p class="muted small">' + esc(t.bootStale) + "</p>";
      if (bp.slowdowns && bp.slowdowns.length) {
        b += '<p class="small">' + esc(t.bootSlow) + "</p><ul>" + bp.slowdowns.slice(0, 4).map(function (s) {
          return "<li>" + esc(String(s.key).replace(/^\d+\s+/, "")) + " · +" + esc(fmtNum(s.avgDelaySec)) + " s (×" + s.count + ")</li>";
        }).join("") + "</ul>";
      }
      out.push(card(t.bootTitle, b));
    }

    // File system scan.
    var vs = a.volumeScan || [];
    if (vs.length) out.push(card(t.fsTitle, "<ul>" + vs.map(function (v) {
      var ok = /NoErrorsFound/i.test(v.result);
      return "<li><strong>" + esc(v.drive) + "</strong> " + (ok ? '<span class="good">' + esc(t.fsOk) + "</span>" : '<span class="bad">' + esc(t.fsBad) + "</span> <code>" + esc(v.result) + "</code>") + "</li>";
    }).join("") + "</ul>"));

    // System files.
    if (a.sfc) {
      var bad = a.sfc.exitCode !== 0 || (a.sfc.lastLines || []).join(" ").match(/corrupt|endommag|violation/i);
      out.push(card(t.sfcTitle, "<p class=\"" + (bad ? "bad" : "good") + "\">" + esc(bad ? t.sfcBad : t.sfcOk) + "</p>"));
    }
    $("admin-out").innerHTML = out.join("");
  }

  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("[data-install]");
    if (!b) return;
    var name = b.dataset.install === "smartctl" ? "smartctl" : "WinDbg";
    if (confirm(T().toolConfirm(name))) send({ type: "installTool", tool: b.dataset.install });
  });

  // ---- recommendations + "C'est fait"
  function loadDone() { try { return JSON.parse(localStorage.getItem("dd.done") || "{}"); } catch (e) { return {}; } }
  function saveDone(d) { try { localStorage.setItem("dd.done", JSON.stringify(d)); } catch (e) { } }

  function renderAdvice(areas) {
    var lib = window.ADVICE[state.lang], seen = {}, list = [], t = T();
    var findings = [];
    areas.forEach(function (a, ai) { (a.findings || []).forEach(function (f) { findings.push({ f: f, ai: ai }); }); });
    findings.sort(function (x, y) { return (order[x.f.level] - order[y.f.level]) || (x.ai - y.ai); });
    findings.forEach(function (o) {
      var id = window.ADVICE_MAP[o.f.id];
      if (id && !seen[id] && lib.items[id]) { seen[id] = true; list.push({ id: id, level: o.f.level, item: lib.items[id] }); }
    });
    var done = loadDone(), curName = fileName(state.current.path);
    $("advice-block").hidden = list.length === 0;
    $("advice").innerHTML = list.map(function (x, i) {
      var it = x.item;
      var mark = done[x.id];
      var isDone = mark && mark === curName;              // marked on this very check
      var stillThere = mark && mark < curName;            // marked on an older check, problem still here
      var opens = (it.open || []).map(function (k) {
        return '<button type="button" class="secondary small-btn" data-open="' + esc(k) + '">' + openIcon + esc(lib.open[k] || k) + "</button>";
      }).join("");
      return '<li class="card advice-item lvl-' + x.level + (i >= 5 ? " extra" : "") + (isDone ? " done" : "") + '" data-advice="' + x.id + '"' + (i >= 5 ? " hidden" : "") + ">" +
        '<details><summary><span class="advice-n">' + (isDone ? icons.green : i + 1) + '</span><span class="advice-title">' + esc(it.title) + "</span>" +
        '<span class="who who-' + it.who + '">' + esc(lib.who[it.who]) + "</span></summary>" +
        '<div class="advice-body">' +
        (stillThere ? '<p class="still">' + esc(t.stillThere) + "</p>" : "") +
        "<h4>" + esc(t.whatLabel) + "</h4><p>" + gloss(esc(it.what)) + "</p>" +
        "<h4>" + esc(t.whyLabel) + "</h4><p>" + gloss(esc(it.why)) + "</p>" +
        "<h4>" + esc(t.howLabel) + "</h4><ol>" + it.how.map(function (s) { return "<li>" + gloss(esc(s)) + "</li>"; }).join("") + "</ol>" +
        '<div class="open-row">' + opens +
        '<button type="button" class="secondary small-btn done-btn" data-done="' + x.id + '" aria-pressed="' + !!isDone + '">' + icons.green + esc(isDone ? t.doneUndo : t.doneMark) + "</button></div>" +
        "</div></details></li>";
    }).join("");
    var extra = list.length - 5, more = $("btn-more-advice");
    more.hidden = extra <= 0;
    if (extra > 0) {
      more.textContent = t.moreAdvice(extra);
      more.onclick = function () { document.querySelectorAll(".advice-item.extra").forEach(function (el) { el.hidden = false; }); more.hidden = true; };
    }
    var first = document.querySelector(".advice-item:not(.done) details");
    if (first) first.open = true;
    return list.map(function (x) { return x.id; });
  }

  var openIcon = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/></svg>';

  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("[data-open]");
    if (b) { send({ type: "open", target: b.dataset.open }); return; }
    var d = e.target.closest && e.target.closest("[data-done]");
    if (d && state.current) {
      var done = loadDone(), id = d.dataset.done, cur = fileName(state.current.path);
      if (done[id] === cur) delete done[id]; else done[id] = cur;
      saveDone(done);
      var li = d.closest(".advice-item"), isDone = done[id] === cur, t = T();
      li.classList.toggle("done", isDone);
      d.setAttribute("aria-pressed", isDone);
      d.innerHTML = icons.green + esc(isDone ? t.doneUndo : t.doneMark);
      var n = li.querySelector(".advice-n");
      n.innerHTML = isDone ? icons.green : String(Array.prototype.indexOf.call(li.parentNode.children, li) + 1);
      if (isDone) { li.querySelector("details").open = false; toast(t.doneToast); }
    }
  });

  // ---- since the previous check
  var sinceCtx = null;
  function startSince(path, adviceIds) {
    var idx = state.history.findIndex(function (h) { return h.path === path; });
    var prev = idx >= 0 ? state.history[idx + 1] : null;
    var cur = fileName(path);
    // "C'est fait" verification: advice marked on an older check that no longer shows up is fixed.
    var done = loadDone(), fixed = [];
    Object.keys(done).forEach(function (id) {
      if (done[id] < cur && adviceIds.indexOf(id) < 0) { fixed.push(id); delete done[id]; }
    });
    if (fixed.length) saveDone(done);
    sinceCtx = { fixed: fixed, prevName: prev ? prev.name : null, curName: cur };
    $("since-block").hidden = !prev && !fixed.length;
    $("since-list").innerHTML = '<li class="muted">' + esc(T().comparing) + "</li>";
    if (prev) send({ type: "compare", current: path, previous: prev.path, id: "since" });
    else renderSince(null);
  }

  function scoreOf(name) {
    for (var i = 0; i < state.points.length; i++) if (state.points[i].name === name) return state.points[i].score;
    return null;
  }

  function sinceItems(c, prevName, curName) {
    var t = T(), items = [];
    var ps = prevName ? scoreOf(prevName) : null, cs = curName ? scoreOf(curName) : null;
    if (ps != null && cs != null && ps !== cs) items.push({ cls: cs > ps ? "good" : "bad", text: t.scoreDelta(ps, cs) });
    if (!c || !c.comparable) return items;
    (c.volumes || []).forEach(function (v) {
      if (v.deltaFreeGB != null && Math.abs(v.deltaFreeGB) >= 1)
        items.push({ cls: v.deltaFreeGB > 0 ? "good" : "bad", text: t.spaceDelta(v.drive, (v.deltaFreeGB > 0 ? "+" : "") + fmtNum(v.deltaFreeGB)) });
    });
    var st = c.stability || {};
    var crashes = (st.newUnexpectedShutdowns || 0) + (st.newBugchecks || []).length;
    if (crashes) items.push({ cls: "bad", text: t.newCrashes(crashes) });
    var count = function (arr) { return (arr || []).reduce(function (s, g) { return s + (g.count || 1); }, 0); };
    var groups = [["newGpuEvents", "newGpu"], ["newDiskEvents", "newDisk"], ["newHardwareErrors", "newHw"], ["newCpuThrottleEvents", "newThrottle"], ["newNetworkDrops", "newNet"]];
    groups.forEach(function (g) { var n = count(c[g[0]]); if (n) items.push({ cls: "bad", text: t[g[1]](n) }); });
    if (!crashes && !groups.some(function (g) { return count(c[g[0]]); })) items.push({ cls: "good", text: t.nothingNew });
    return items;
  }

  function renderSince(c) {
    var t = T(), lib = window.ADVICE[state.lang];
    var items = sinceItems(c, sinceCtx.prevName, sinceCtx.curName);
    sinceCtx.fixed.forEach(function (id) { if (lib.items[id]) items.unshift({ cls: "good", text: t.fixedNow(lib.items[id].title) }); });
    if (!items.length) { $("since-block").hidden = true; return; }
    $("since-title").textContent = sinceCtx.prevName ? t.sinceTitle(formatDate(sinceCtx.prevName, true)) : t.sinceTitleNone;
    $("since-list").innerHTML = items.map(function (i) { return '<li class="' + i.cls + '">' + esc(i.text) + "</li>"; }).join("");
  }

  // ---- technician view
  function renderTech(d) {
    var rows = Object.keys(d.facts || {}).map(function (k) {
      var v = d.facts[k];
      return "<tr><td>" + esc(k) + "</td><td>" + esc(v === null ? "—" : typeof v === "object" ? JSON.stringify(v) : v) + "</td></tr>";
    }).join("");
    var fired = [];
    (d.areas || []).forEach(function (a) { (a.findings || []).forEach(function (f) { fired.push(a.id + " / " + f.id + " (" + f.level + ")"); }); });
    $("tech-out").innerHTML =
      "<p><strong>" + esc(T().techRules) + "</strong> " + esc(fired.join(" · ") || "—") + "</p>" +
      "<p><strong>" + esc(T().techSnapshot) + "</strong> <code>" + esc(state.current.path) + "</code> · rules v" + esc(d.rulesVersion) + "</p>" +
      '<table class="facts"><thead><tr><th>' + esc(T().techFact) + "</th><th>" + esc(T().techValue) + "</th></tr></thead><tbody>" + rows + "</tbody></table>";
  }

  $("btn-tech").addEventListener("click", function () {
    state.tech = !state.tech;
    this.setAttribute("aria-pressed", state.tech);
    $("tech-block").hidden = !state.tech;
    if (state.tech) {
      $("tech-out").textContent = T().scoring;
      requestScore(state.current.path, "tech", true);
      $("tech-block").scrollIntoView({ behavior: "smooth", block: "start" });
    }
  });

  // ---- copy for a forum (Markdown, no personal data: the findings carry only counts and sizes)
  function forumText() {
    var d = state.current.data, t = T(), lines = [];
    lines.push("**DesktopDiag** · " + d.score + "/100 · " + formatDate(fileName(state.current.path)));
    lines.push("");
    lines.push("| " + t.forumArea + " | " + t.forumStatus + " | " + t.forumFindings + " |");
    lines.push("|---|---|---|");
    sortedAreas(d).forEach(function (a) {
      if (a.level === "skipped") return;
      lines.push("| " + a.label + " | " + t.level[a.level] + " | " + ((a.findings || []).map(function (f) { return f.text; }).join("; ") || "-") + " |");
    });
    var titles = Array.prototype.map.call(document.querySelectorAll(".advice-item .advice-title"), function (el) { return el.textContent; });
    if (titles.length) { lines.push(""); lines.push("**" + t.todo + "**"); titles.forEach(function (x, i) { lines.push((i + 1) + ". " + x); }); }
    lines.push("");
    lines.push("_" + t.forumFooter + "_");
    return lines.join("\n");
  }
  function copyForum() { if (state.current) send({ type: "copy", text: forumText() }); }
  $("btn-copy").addEventListener("click", copyForum);

  // ---- PDF (WebView2 print to PDF; print CSS shows everything unfolded, light colors)
  var printState = null;
  function savePdf() {
    if (!state.current) return;
    printState = Array.prototype.map.call(document.querySelectorAll("#screen-results details"), function (el) { var o = el.open; el.open = true; return [el, o]; });
    document.querySelectorAll(".advice-item.extra").forEach(function (el) { el.hidden = false; });
    send({ type: "pdf", name: fileName(state.current.path) });
  }
  function endPrint() {
    if (printState) printState.forEach(function (p) { p[0].open = p[1]; });
    printState = null;
  }
  $("btn-pdf").addEventListener("click", savePdf);

  // ---- compare two checks
  var cmp = $("compare-dlg");
  $("btn-compare").addEventListener("click", function () {
    var opts = state.history.map(function (h) {
      var s = scoreOf(h.name);
      return '<option value="' + esc(h.path) + '">' + esc(formatDate(h.name) + (s != null ? " · " + s + "/100" : "")) + "</option>";
    }).join("");
    $("cmp-a").innerHTML = opts;
    $("cmp-b").innerHTML = opts;
    var cur = state.current ? state.current.path : (state.history[0] || {}).path;
    var idx = state.history.findIndex(function (h) { return h.path === cur; });
    $("cmp-b").selectedIndex = Math.max(0, idx);
    $("cmp-a").selectedIndex = Math.min(state.history.length - 1, Math.max(0, idx) + 1);
    $("cmp-out").innerHTML = "";
    cmp.showModal();
  });
  $("btn-compare-home").addEventListener("click", function () { $("btn-compare").click(); });
  $("cmp-go").addEventListener("click", function (e) {
    e.preventDefault();
    var a = $("cmp-a").value, b = $("cmp-b").value;
    if (a === b) { $("cmp-out").textContent = T().cmpSame; return; }
    // Always compare older -> newer.
    if (fileName(a) > fileName(b)) { var x = a; a = b; b = x; }
    cmp.dataset.prev = fileName(a); cmp.dataset.cur = fileName(b);
    $("cmp-out").innerHTML = '<p class="muted">' + esc(T().comparing) + "</p>";
    send({ type: "compare", current: b, previous: a, id: "dialog" });
  });
  function renderCompareDialog(c) {
    var items = sinceItems(c, cmp.dataset.prev, cmp.dataset.cur);
    $("cmp-out").innerHTML = '<p class="muted">' + esc(T().cmpBetween(formatDate(cmp.dataset.prev, true), formatDate(cmp.dataset.cur, true))) + "</p>" +
      '<ul class="since">' + items.map(function (i) { return '<li class="' + i.cls + '">' + esc(i.text) + "</li>"; }).join("") + "</ul>";
  }

  function showError(msg) { $("error-detail").textContent = msg || ""; show("error"); }

  // ---------------------------------------------------------------- running
  var timer = null, runPhase = "collect", phaseStart = 0;
  function loadOpts() { try { return JSON.parse(localStorage.getItem("dd.deep") || "{}"); } catch (e) { return {}; } }
  function saveOpts() {
    try { localStorage.setItem("dd.deep", JSON.stringify({ admin: $("opt-admin").checked, dumps: $("opt-dumps").checked, sfc: $("opt-sfc").checked })); } catch (e) { }
  }
  (function () {
    var o = loadOpts();
    if (o.admin) $("opt-admin").checked = true;
    if (o.dumps === false) $("opt-dumps").checked = false;
    if (o.sfc) $("opt-sfc").checked = true;
    $("deep-opts").hidden = !$("opt-admin").checked;
  })();
  ["opt-admin", "opt-dumps", "opt-sfc"].forEach(function (id) {
    $(id).addEventListener("change", function () { $("deep-opts").hidden = !$("opt-admin").checked; saveOpts(); });
  });

  function startCheck() {
    show("running");
    var t = T(), i = 0, j = 0, start = Date.now();
    var admin = $("opt-admin").checked;
    runPhase = "collect";
    $("running-msg").textContent = t.msgs[0];
    $("progress-bar").style.width = "2%";
    clearInterval(timer);
    timer = setInterval(function () {
      var s = (Date.now() - start) / 1000, pct;
      if (runPhase === "collect") {
        // Eases towards 95 % (60 % with the deep scan) over about a minute.
        pct = (admin ? 60 : 95) * (1 - Math.exp(-s / 22));
        if (Math.floor(s / 4) > i && i < T().msgs.length - 1) { i++; $("running-msg").textContent = T().msgs[i]; }
      } else if (runPhase === "ask") {
        pct = parseFloat($("progress-bar").style.width) || 60;
      } else {
        var a = (Date.now() - phaseStart) / 1000;
        pct = 60 + 35 * (1 - Math.exp(-a / 90));
        if (Math.floor(a / 8) > j && j < T().adminMsgs.length - 1) { j++; $("running-msg").textContent = T().adminMsgs[j]; }
      }
      $("progress-bar").style.width = pct.toFixed(1) + "%";
      if ($("screen-running").hidden) clearInterval(timer);
    }, 250);
    send({ type: "runCheck", admin: admin, dumps: admin && $("opt-dumps").checked, sfc: admin && $("opt-sfc").checked });
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
      if (!$("screen-results").hidden && state.current) requestScore(state.current.path, "result");
      else if (!$("screen-home").hidden) renderHome();
    });
  });

  var dlg = $("settings");
  $("btn-settings").addEventListener("click", function () {
    dlg.querySelector('input[name=theme][value="' + state.theme + '"]').checked = true;
    dlg.querySelector('input[name=size][value="' + state.textSize + '"]').checked = true;
    $("opt-autoupdate").checked = !state.noUpdateCheck;
    dlg.showModal();
  });
  dlg.addEventListener("change", function (e) {
    if (e.target.id === "opt-autoupdate") {
      state.noUpdateCheck = !e.target.checked;
      send({ type: "saveSettings", noUpdateCheck: state.noUpdateCheck });
      return;
    }
    if (e.target.name === "theme") state.theme = e.target.value;
    if (e.target.name === "size") state.textSize = +e.target.value;
    applySettings(null, true);
  });

  // ---- updates
  $("btn-check-update").addEventListener("click", function () {
    $("update-status").textContent = T().checking;
    send({ type: "checkUpdate", force: true });
  });
  $("btn-update").addEventListener("click", function () {
    this.disabled = true;
    $("update-progress").hidden = false;
    $("update-bar").style.width = "0%";
    send({ type: "doUpdate" });
  });
  $("btn-update-later").addEventListener("click", function () { $("update-banner").hidden = true; });

  var wn = $("whatsnew");
  function longDate(iso, withTime) {
    var d = new Date(iso);
    if (isNaN(d)) return iso;
    var s = d.toLocaleDateString(locale(), { day: "numeric", month: "long", year: "numeric" });
    return withTime ? s + " · " + d.toLocaleTimeString(locale(), { hour: "2-digit", minute: "2-digit" }) : s;
  }

  function showWhatsNew(afterUpdate) {
    var entry = (window.WHATSNEW || {})[state.version];
    var t = T();
    $("whatsnew-title").textContent = afterUpdate ? t.whatsNewUpdated(state.version) : t.whatsNewTitle(state.version);
    // When: date of the update on this PC if there was one, else the release date.
    var meta = [];
    if (state.updatedAt) meta.push(t.updatedOn(longDate(state.updatedAt, true), state.updatedFrom));
    else if (entry && entry.date) meta.push(t.releasedOn(longDate(entry.date + "T12:00:00", false)));
    $("whatsnew-meta").textContent = meta.join(" ");
    $("whatsnew-meta").hidden = !meta.length;
    $("whatsnew-list").innerHTML = entry ? entry[state.lang].map(function (x) { return "<li>" + esc(x) + "</li>"; }).join("") : "<li>" + esc(t.whatsNewNone) + "</li>";
    // A newer version waiting: what changes + link + update button.
    var nv = state.newVersion;
    $("whatsnew-new").hidden = !nv;
    if (nv) {
      $("whatsnew-new-title").textContent = t.updateAvailable(nv.version);
      $("whatsnew-new-notes").textContent = nv.notes || t.whatsNewNone;
    }
    if (!wn.open) wn.showModal();
  }
  $("btn-update-dlg").addEventListener("click", function () { wn.close(); $("btn-update").click(); });
  $("version").addEventListener("click", function () { showWhatsNew(false); });

  // Shortcuts: Enter = run (home), Ctrl+C = copy for a forum (results, nothing selected),
  // Ctrl+P = PDF (results), Escape = home.
  document.addEventListener("keydown", function (e) {
    if (dlg.open || cmp.open || wn.open) return;
    var onResults = !$("screen-results").hidden;
    if (e.key === "Enter" && !$("screen-home").hidden && document.activeElement === document.body) { startCheck(); return; }
    if (e.ctrlKey && (e.key === "c" || e.key === "C") && onResults && !String(window.getSelection())) { e.preventDefault(); copyForum(); return; }
    if (e.ctrlKey && (e.key === "p" || e.key === "P")) { e.preventDefault(); if (onResults) savePdf(); return; }
    if (e.key === "Escape" && (onResults || !$("screen-error").hidden)) renderHome();
  });

  translate();
  send({ type: "init" });
})();
