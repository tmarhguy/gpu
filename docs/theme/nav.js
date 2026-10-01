// Collapsible left TOC for Asciidoctor's built-in `#toc` sidebar.
// No dependencies. Progressive enhancement: without JS the full TOC works.
// With JS: sections start collapsed (major chapters visible); disclosure
// buttons expand/collapse, expanded state persists in localStorage, and the
// hierarchy containing the active section auto-expands.
(function () {
  'use strict';

  var STORAGE_KEY = 'pdocs-nav-v2';
  var toc = document.getElementById('toc');
  if (!toc) return;
  var topList = toc.querySelector('ul');
  if (!topList) return;

  // Load persisted expanded-section ids (href anchors). Tolerate bad data.
  // Fresh visitors (nothing stored) see every section collapsed.
  var expanded = {};
  try {
    var raw = window.localStorage && window.localStorage.getItem(STORAGE_KEY);
    if (raw) expanded = JSON.parse(raw) || {};
  } catch (e) {
    expanded = {};
  }
  function save() {
    try {
      if (window.localStorage) {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(expanded));
      }
    } catch (e) { /* private mode etc: nav still works for the session */ }
  }

  function sectionId(li) {
    var a = li.querySelector(':scope > .nav-row > a, :scope > a');
    if (!a) return null;
    var href = a.getAttribute('href');
    return href && href.charAt(0) === '#' ? href : null;
  }

  // Wrap each nested li: <div class=nav-row><button><a></div> so the title
  // link navigates normally while the button toggles children.
  function enhance(li) {
    var childUl = li.querySelector(':scope > ul');
    var anchor = li.querySelector(':scope > a');
    if (!anchor || anchor.parentNode.className === 'nav-row') return childUl;
    var row = document.createElement('div');
    row.className = 'nav-row';
    li.insertBefore(row, anchor);
    row.appendChild(anchor);
    if (childUl) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'disclosure';
      btn.setAttribute('aria-label', 'Toggle subsection');
      row.insertBefore(btn, anchor);
      btn.addEventListener('click', function () {
        var isCollapsed = li.classList.toggle('collapsed');
        btn.setAttribute('aria-expanded', String(!isCollapsed));
        btn.textContent = isCollapsed ? '\u25B8' : '\u25BE';
        var id = sectionId(li);
        if (id) {
          if (isCollapsed) delete expanded[id];
          else expanded[id] = true;
          save();
        }
      });
    } else {
      // Keep leaf rows aligned with disclosure rows.
      var spacer = document.createElement('span');
      spacer.className = 'disclosure';
      spacer.setAttribute('aria-hidden', 'true');
      row.insertBefore(spacer, anchor);
    }
    return childUl;
  }

  function setCollapsed(li, isCollapsed, updateButton) {
    li.classList.toggle('collapsed', isCollapsed);
    var btn = li.querySelector(':scope > .nav-row > button.disclosure');
    if (btn && updateButton !== false) {
      btn.setAttribute('aria-expanded', String(!isCollapsed));
      btn.textContent = isCollapsed ? '\u25B8' : '\u25BE';
    }
  }

  // Expand li and its ancestors so a section becomes visible.
  // Records the expansion so it survives reloads.
  // Returns true when anything changed (class or stored state).
  function expandBranch(li) {
    var changed = false;
    var node = li;
    while (node) {
      if (node.tagName === 'LI') {
        if (node.classList.contains('collapsed')) {
          setCollapsed(node, false);
          changed = true;
        }
        var id = sectionId(node);
        if (id && !expanded[id]) {
          expanded[id] = true;
          changed = true;
        }
      }
      node = node.parentNode ? node.parentNode.closest('li') : null;
    }
    return changed;
  }

  // Enhance all levels that have children (top level + nested).
  var items = toc.querySelectorAll('li');
  items.forEach(function (li) { enhance(li); });

  // Default state: every section with children starts collapsed, so the
  // reader sees primarily the major chapters. Restore expanded sections.
  items.forEach(function (li) {
    if (!li.querySelector(':scope > ul')) return;
    var id = sectionId(li);
    setCollapsed(li, !(id && expanded[id]));
  });

  // Controls: Collapse all / Expand all (top-level only, unobtrusive).
  var controls = document.createElement('div');
  controls.className = 'nav-controls';
  var collapseBtn = document.createElement('button');
  collapseBtn.type = 'button';
  collapseBtn.textContent = 'Collapse all';
  var expandBtn = document.createElement('button');
  expandBtn.type = 'button';
  expandBtn.textContent = 'Expand all';
  controls.appendChild(collapseBtn);
  controls.appendChild(expandBtn);
  toc.insertBefore(controls, toc.firstChild);

  function topLevelItems() {
    return Array.prototype.slice.call(topList.children).filter(function (el) {
      return el.tagName === 'LI';
    });
  }
  collapseBtn.addEventListener('click', function () {
    topLevelItems().forEach(function (li) {
      if (!li.querySelector(':scope > ul')) return;
      setCollapsed(li, true);
      var id = sectionId(li);
      if (id) delete expanded[id];
    });
    save();
  });
  expandBtn.addEventListener('click', function () {
    toc.querySelectorAll('li.collapsed').forEach(function (li) {
      setCollapsed(li, false);
      var id = sectionId(li);
      if (id) expanded[id] = true;
    });
    save();
  });

  // Active-section highlight + auto-expand ancestors (scroll-spy).
  var links = Array.prototype.slice.call(toc.querySelectorAll('li a[href^="#"]'));
  var targets = links
    .map(function (a) {
      try { return document.querySelector(a.getAttribute('href')); } catch (e) { return null; }
    })
    .filter(Boolean);

  function markActive() {
    var hash = window.location.hash;
    var dirty = false;
    links.forEach(function (a) {
      var on = !!hash && a.getAttribute('href') === hash;
      a.classList.toggle('active', !!on);
      if (on) {
        // Walk up and expand the hierarchy containing this section.
        var li = a.closest('li');
        if (li && expandBranch(li)) dirty = true;
      }
    });
    if (dirty) save();
  }

  // Scroll-spy: pick the last section heading above the viewport middle.
  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      ticking = false;
      if (window.location.hash) { markActive(); return; }
      var mid = window.scrollY + window.innerHeight * 0.3;
      var current = null;
      targets.forEach(function (t) {
        if (t.offsetTop <= mid) current = t;
      });
      var dirty = false;
      links.forEach(function (a) {
        var on = !!current && a.getAttribute('href') === '#' + current.id;
        a.classList.toggle('active', on);
        if (on) {
          // Keep the active hierarchy expanded while scrolling.
          var li = a.closest('li');
          if (li && expandBranch(li)) dirty = true;
        }
      });
      if (dirty) save();
    });
  }

  window.addEventListener('hashchange', markActive);
  window.addEventListener('scroll', onScroll, { passive: true });
  markActive();
  onScroll();
})();
