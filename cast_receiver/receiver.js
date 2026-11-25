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

  function report(message) {
    statusElement.textContent = message;
    context.setApplicationState(message);
    console.info(`[tunebox-cast] ${message}`);
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
        if (media.contentType.startsWith('audio/')) {
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

  setInterval(synchronize, 250);
  context.start();
  report('Receiver ready');
})();
