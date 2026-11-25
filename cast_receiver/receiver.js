'use strict';

(() => {
  const syncToleranceSeconds = 0.2;
  const syncAudio = document.getElementById('sync-audio');
  const videoPlayer = document.getElementById('video-player');
  const audioPlayer = document.getElementById('audio-player');
  const statusElement = document.getElementById('sync-status');
  const context = cast.framework.CastReceiverContext.getInstance();
  const playerManager = context.getPlayerManager();

  let hasSyncAudio = false;
  let maxObservedDrift = 0;
  let lastSyncReport = 0;

  const main = document.querySelector('main');
  const ui = {
    backdrop: document.getElementById('backdrop'),
    idle: document.getElementById('idle'),
    now: document.getElementById('now'),
    art: document.getElementById('art'),
    title: document.getElementById('title'),
    artist: document.getElementById('artist'),
    bar: document.getElementById('bar'),
    elapsed: document.getElementById('elapsed'),
    state: document.getElementById('state'),
    total: document.getElementById('total'),
  };
  const spanish = (navigator.language || '').toLowerCase().startsWith('es');
  const words = spanish
    ? { paused: 'En pausa', buffering: 'Cargando…' }
    : { paused: 'Paused', buffering: 'Loading…' };

  // The status line is a measuring tool for the A/V experiment; on an
  // ordinary track it was the only thing on screen and read as an error.
  function report(message) {
    statusElement.textContent = message;
    statusElement.hidden = !hasSyncAudio;
    context.setApplicationState(message);
    console.info(`[tunebox-cast] ${message}`);
  }

  function clock(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0) {
      return '';
    }
    const whole = Math.floor(seconds);
    const hours = Math.floor(whole / 3600);
    const minutes = Math.floor((whole % 3600) / 60);
    const rest = String(whole % 60).padStart(2, '0');
    return hours > 0
      ? `${hours}:${String(minutes).padStart(2, '0')}:${rest}`
      : `${minutes}:${rest}`;
  }

  let shownArt = null;

  // Text goes in through textContent only: titles come from YouTube.
  function showTrack() {
    const media = playerManager.getMediaInformation();
    const metadata = media?.metadata;
    if (!metadata) {
      return;
    }
    ui.title.textContent = metadata.title || '';
    ui.artist.textContent = metadata.artist || metadata.subtitle || '';
    const art = mediaUrl(metadata.images?.[0]?.url);
    if (art !== shownArt) {
      shownArt = art;
      ui.backdrop.classList.remove('shown');
      if (art) {
        ui.art.src = art;
        ui.backdrop.style.backgroundImage = `url("${art}")`;
        ui.backdrop.classList.add('shown');
      } else {
        ui.art.removeAttribute('src');
        ui.backdrop.style.backgroundImage = '';
      }
    }
  }

  function tick() {
    const state = playerManager.getPlayerState();
    const loaded = state !== cast.framework.messages.PlayerState.IDLE &&
      playerManager.getMediaInformation() != null;
    ui.idle.hidden = loaded;
    ui.now.hidden = !loaded;
    if (!loaded) {
      return;
    }

    const position = playerManager.getCurrentTimeSec();
    const length = playerManager.getDurationSec();
    ui.elapsed.textContent = clock(position) || '0:00';
    ui.total.textContent = clock(length);
    const share = length > 0 ? Math.min(1, Math.max(0, position / length)) : 0;
    ui.bar.style.transform = `scaleX(${share})`;
    ui.state.textContent =
      state === cast.framework.messages.PlayerState.PAUSED
        ? words.paused
        : state === cast.framework.messages.PlayerState.BUFFERING
          ? words.buffering
          : '';
  }

  function clearSyncAudio() {
    hasSyncAudio = false;
    syncAudio.pause();
    syncAudio.removeAttribute('src');
    syncAudio.load();
    maxObservedDrift = 0;
  }

  function mediaUrl(value) {
    if (typeof value !== 'string') {
      return null;
    }

    try {
      const url = new URL(value);
      if (
        (url.protocol !== 'http:' && url.protocol !== 'https:') ||
        url.username ||
        url.password
      ) {
        return null;
      }
      return url.href;
    } catch {
      return null;
    }
  }

  function waitForAudio(url) {
    return new Promise((resolve) => {
      let settled = false;
      const finish = (ready) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timeout);
        syncAudio.removeEventListener('canplay', onCanPlay);
        syncAudio.removeEventListener('error', onError);
        resolve(ready);
      };
      const onCanPlay = () => finish(true);
      const onError = () => finish(false);
      const timeout = setTimeout(() => finish(false), 15000);

      syncAudio.addEventListener('canplay', onCanPlay);
      syncAudio.addEventListener('error', onError);
      syncAudio.src = url;
      syncAudio.load();
      if (syncAudio.readyState >= HTMLMediaElement.HAVE_FUTURE_DATA) {
        finish(true);
      }
    });
  }

  function loadError(reason) {
    const error = new cast.framework.messages.ErrorData(
      cast.framework.messages.ErrorType.LOAD_FAILED,
    );
    error.reason = reason;
    return error;
  }

  function positionAudio() {
    if (!hasSyncAudio || syncAudio.readyState < HTMLMediaElement.HAVE_METADATA) {
      return;
    }

    const target = videoPlayer.currentTime;
    syncAudio.currentTime = Number.isFinite(syncAudio.duration)
      ? Math.min(target, syncAudio.duration)
      : target;
  }

  function startSyncAudio() {
    if (!hasSyncAudio) {
      return;
    }

    positionAudio();
    if (videoPlayer.paused) {
      syncAudio.pause();
      return;
    }

    syncAudio.play().catch(() => {
      report('A/V sync error: separate audio could not start');
      playerManager.pause();
    });
  }

  function synchronize() {
    if (
      !hasSyncAudio ||
      videoPlayer.paused ||
      videoPlayer.ended ||
      syncAudio.readyState < HTMLMediaElement.HAVE_FUTURE_DATA
    ) {
      return;
    }

    const drift = videoPlayer.currentTime - syncAudio.currentTime;
    const absoluteDrift = Math.abs(drift);
    maxObservedDrift = Math.max(maxObservedDrift, absoluteDrift);

    if (absoluteDrift > syncToleranceSeconds) {
      positionAudio();
    }

    const now = Date.now();
    if (now - lastSyncReport >= 2000) {
      lastSyncReport = now;
      report(
        `A/V drift ${absoluteDrift.toFixed(3)}s · max ${maxObservedDrift.toFixed(3)}s`,
      );
    }
  }

  videoPlayer.addEventListener('play', startSyncAudio);
  videoPlayer.addEventListener('playing', startSyncAudio);
  videoPlayer.addEventListener('pause', () => syncAudio.pause());
  videoPlayer.addEventListener('waiting', () => syncAudio.pause());
  videoPlayer.addEventListener('seeking', () => syncAudio.pause());
  videoPlayer.addEventListener('seeked', startSyncAudio);
  videoPlayer.addEventListener('timeupdate', synchronize);
  videoPlayer.addEventListener('ended', () => syncAudio.pause());
  syncAudio.addEventListener('error', () => {
    if (hasSyncAudio) {
      report('A/V sync error: separate audio failed to load');
      playerManager.pause();
    }
  });

  playerManager.setMediaElement(videoPlayer);
  playerManager.setMessageInterceptor(
    cast.framework.messages.MessageType.LOAD,
    async (request) => {
      const media = request.media;
      const customData = media?.customData?.tuneboxCast;
      clearSyncAudio();

      if (!media || !media.contentType) {
        return loadError(cast.framework.messages.ErrorReason.INVALID_PARAM);
      }

      if (customData == null) {
        const audio = media.contentType.startsWith('audio/');
        main.classList.toggle('video', !audio);
        if (audio) {
          playerManager.setMediaElement(audioPlayer);
        } else {
          playerManager.setMediaElement(videoPlayer);
        }
        report('Receiver ready');
        return request;
      }

      if (
        customData.version !== 1 ||
        !media.contentType.startsWith('video/')
      ) {
        return loadError(cast.framework.messages.ErrorReason.INVALID_PARAM);
      }

      const audioUrl = mediaUrl(customData.audioUrl);
      if (!audioUrl) {
        return loadError(cast.framework.messages.ErrorReason.INVALID_PARAM);
      }

      main.classList.add('video');
      playerManager.setMediaElement(videoPlayer);
      if (!(await waitForAudio(audioUrl))) {
        return loadError(cast.framework.messages.ErrorReason.INVALID_REQUEST);
      }

      hasSyncAudio = true;
      positionAudio();
      report('A/V tracks ready');
      return request;
    },
  );

  playerManager.addEventListener(
    cast.framework.events.EventType.PLAYER_LOAD_COMPLETE,
    showTrack,
  );
  setInterval(synchronize, 250);
  setInterval(tick, 500);
  context.start();
  report('Receiver ready');
})();
