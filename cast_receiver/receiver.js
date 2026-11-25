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
  const root = document.documentElement;
  const ui = {
    backdropArt: document.getElementById('backdrop-art'),
    idle: document.getElementById('idle'),
    idleHint: document.getElementById('idle-hint'),
    now: document.getElementById('now'),
    art: document.getElementById('art'),
    title: document.getElementById('title'),
    artist: document.getElementById('artist'),
    bar: document.getElementById('bar'),
    thumb: document.getElementById('thumb'),
    elapsed: document.getElementById('elapsed'),
    total: document.getElementById('total'),
    state: document.getElementById('state'),
    stateIcon: document.getElementById('state-icon'),
    stateText: document.getElementById('state-text'),
    next: document.getElementById('next'),
  };
  const spanish = (navigator.language || '').toLowerCase().startsWith('es');
  const words = spanish
    ? {
        paused: 'En pausa',
        buffering: 'Cargando…',
        upNext: 'A continuación',
        idle: 'Elige una canción en Tunebox y transmítela a esta pantalla.',
      }
    : {
        paused: 'Paused',
        buffering: 'Loading…',
        upNext: 'Up next',
        idle: 'Pick a song in Tunebox and cast it to this screen.',
      };
  // Material icons' paths, so the shapes match the phone's buttons.
  const icons = {
    pause: 'M6 19h4V5H6v14zm8-14v14h4V5h-4z',
    hourglass: 'M6 2v6h.01L6 8.01 10 12l-4 4 .01.01H6V22h12v-5.99h-.01L18 16l-4-4 4-3.99-.01-.01H18V2H6z',
  };
  const colourKeys = {
    surface: '--surface',
    onSurface: '--on-surface',
    onSurfaceVariant: '--on-surface-variant',
    primary: '--primary',
    onPrimary: '--on-primary',
    track: '--track',
  };
  ui.idleHint.textContent = words.idle;

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

  // The phone sends its theme with every track. Anything that is not a plain
  // #rrggbb is ignored rather than handed to the style sheet.
  function applyColours(colours) {
    if (!colours || typeof colours !== 'object') {
      return;
    }
    for (const [key, property] of Object.entries(colourKeys)) {
      const value = colours[key];
      if (typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value)) {
        root.style.setProperty(property, value);
        if (key === 'surface') {
          const rgb = [1, 3, 5].map((i) => parseInt(value.slice(i, i + 2), 16));
          root.style.setProperty('--surface-rgb', rgb.join(' '));
        }
      }
    }
  }

  function text(value) {
    return typeof value === 'string' ? value : '';
  }

  let shownArt = null;

  // Text goes in through textContent only: titles come from YouTube.
  function showTrack() {
    const media = playerManager.getMediaInformation();
    const metadata = media?.metadata;
    if (!metadata) {
      return;
    }
    const screen = media.customData?.tuneboxScreen ?? {};
    applyColours(screen.colors);

    ui.title.textContent = text(metadata.title);
    ui.artist.textContent = text(metadata.artist) || text(metadata.subtitle);
    const next = text(screen.next);
    ui.next.hidden = !next;
    ui.next.textContent = `${text(screen.upNext) || words.upNext}: ${next}`;

    const art = mediaUrl(metadata.images?.[0]?.url);
    if (art !== shownArt) {
      shownArt = art;
      ui.backdropArt.classList.remove('shown');
      if (art) {
        ui.art.src = art;
        ui.backdropArt.style.backgroundImage = `url("${art}")`;
        ui.backdropArt.classList.add('shown');
      } else {
        ui.art.removeAttribute('src');
        ui.backdropArt.style.backgroundImage = '';
      }
    }
  }

  let shownState = null;

  function showState(state) {
    if (state === shownState) {
      return;
    }
    shownState = state;
    const { PAUSED, BUFFERING } = cast.framework.messages.PlayerState;
    const icon = state === PAUSED ? icons.pause
      : state === BUFFERING ? icons.hourglass
        : null;
    ui.state.hidden = icon == null;
    if (icon) {
      ui.stateIcon.innerHTML = `<path d="${icon}"/>`;
      ui.stateText.textContent = state === PAUSED ? words.paused : words.buffering;
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
    ui.thumb.style.left = `${share * 100}%`;
    showState(state);
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

  // Temporary probe: which of the remote's buttons reach this page, and as
  // what. A key that arrives as a keydown can be bound to an action here; one
  // the framework turns into a command shows up as a request instead.
  const keyLog = document.getElementById('keys');
  function logInput(line) {
    const item = document.createElement('li');
    const time = new Date().toLocaleTimeString();
    item.textContent = `${time}  ${line}`;
    keyLog.prepend(item);
    while (keyLog.children.length > 8) {
      keyLog.lastChild.remove();
    }
    console.info(`[tunebox-keys] ${line}`);
  }
  for (const type of ['keydown', 'keyup']) {
    window.addEventListener(type, (event) => {
      logInput(`${type} key=${event.key} code=${event.code} keyCode=${event.keyCode}`);
    }, true);
  }
  const requests = [
    'REQUEST_PLAY', 'REQUEST_PAUSE', 'REQUEST_SEEK', 'REQUEST_STOP',
    'REQUEST_QUEUE_UPDATE', 'REQUEST_VOLUME_CHANGE', 'REQUEST_SKIP_AD',
  ];
  for (const name of requests) {
    const type = cast.framework.events.EventType[name];
    if (type) {
      playerManager.addEventListener(type, (event) => {
        const from = event.senderId ?? event.requestData?.senderId ?? '?';
        logInput(`${name} from=${from}`);
      });
    }
  }
  // Some TVs only send keys to a page that holds focus.
  document.body.tabIndex = -1;
  window.addEventListener('load', () => document.body.focus());

  setInterval(synchronize, 250);
  setInterval(tick, 500);
  context.start();
  report('Receiver ready');
})();
