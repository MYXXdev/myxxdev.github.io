/* MYbloXX App Control 49 */
(function () {
  'use strict';
  if (window.__MYBAppControl) { window.__MYBAppControl.setEnabled(__MYB_INITIAL_ENABLED__); return; }
  var enabled = __MYB_INITIAL_ENABLED__, multiplier = 100;
  var timeout = window.setTimeout, interval = window.setInterval;
  var realDate = Date.now.bind(Date), realPerformance = window.performance && performance.now.bind(performance);
  var dateOrigin = realDate(), performanceOrigin = realPerformance ? realPerformance() : 0;
  var media = [], candidates = [100, 64, 32, 16, 8, 4, 2];
  function delay(value) { var number = Number(value) || 0; return enabled && number > 0 ? Math.max(4, number / multiplier) : number; }
  window.setTimeout = function (fn, ms) { return timeout.apply(this, [fn, delay(ms)].concat([].slice.call(arguments, 2))); };
  window.setInterval = function (fn, ms) { return interval.apply(this, [fn, delay(ms)].concat([].slice.call(arguments, 2))); };
  Date.now = function () { var now = realDate(); return enabled ? dateOrigin + (now - dateOrigin) * multiplier : now; };
  if (realPerformance) { try { Object.defineProperty(performance, 'now', { configurable: true, value: function () { var now = realPerformance(); return enabled ? performanceOrigin + (now - performanceOrigin) * multiplier : now; } }); } catch (_) {} }
  function apply(video) {
    if (!enabled) return;
    if (!video.__mybRegistered) {
      video.__mybRegistered = true; video.__mybOriginalRate = video.playbackRate || 1; media.push(video);
      video.addEventListener('ratechange', function () {
        if (!enabled || this.__mybSetting) return;
        if (this.__mybRate && Math.abs(this.playbackRate - this.__mybRate) > .01) apply(this);
      }, true);
    }
    if (video.__mybRate) {
      if (Math.abs(video.playbackRate - video.__mybRate) <= .01) return;
      video.__mybSetting = true;
      try { video.playbackRate = video.__mybRate;
        var current = video.playbackRate;
        if (current > 1 && current <= video.__mybRate) { video.__mybRate = current; video.__mybSetting = false; return; }
      } catch (_) {}
      video.__mybRate = 0; video.__mybSetting = false;
    }
    video.__mybSetting = true;
    for (var i = 0; i < candidates.length; i++) {
      try { video.playbackRate = candidates[i]; var accepted = video.playbackRate;
        if (accepted > 1 && accepted <= candidates[i] && accepted <= multiplier) { video.__mybRate = accepted; break; }
      } catch (_) {}
    }
    video.__mybSetting = false;
  }
  function scan() {
    if (!enabled) return;
    var videos = document.getElementsByTagName('video');
    for (var i = 0; i < videos.length; i++) apply(videos[i]);
  }
  function setEnabled(value) {
    var next = !!value;
    if (next && !enabled) { dateOrigin = realDate(); performanceOrigin = realPerformance ? realPerformance() : 0; }
    enabled = next;
    if (!enabled) media.forEach(function (video) { try { video.playbackRate = video.__mybOriginalRate; } catch (_) {} });
    else scan();
    for (var i = 0; i < window.frames.length; i++) { try { window.frames[i].postMessage({ mybAcceleration: enabled }, '*'); } catch (_) {} }
  }
  window.__MYBAppControl = { setEnabled: setEnabled, requestedRate: multiplier };
  window.addEventListener('message', function (event) {
    if ((event.source === window.parent || event.source === window) && event.data && typeof event.data.mybAcceleration === 'boolean') setEnabled(event.data.mybAcceleration);
  });
  document.addEventListener('play', scan, true);
  document.addEventListener('loadedmetadata', scan, true);
  interval.call(window, scan, 1000);
  scan();
})();
