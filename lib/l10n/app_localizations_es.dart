// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navSearch => 'Buscar';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get themeTooltip => 'Tema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Según el sistema';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutBody =>
      'Se borrarán las cookies guardadas en este dispositivo.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get searchHint => 'Buscar canciones o artistas';

  @override
  String get filterAll => 'Todo';

  @override
  String get filterSongs => 'Canciones';

  @override
  String get filterVideos => 'Vídeos';

  @override
  String get searchStartTitle => 'Busca algo para empezar';

  @override
  String get searchStartBody =>
      'Canciones, artistas o álbumes de YouTube Music.';

  @override
  String get searchEmptyTitle => 'Sin resultados';

  @override
  String get searchEmptyBody => 'Prueba con otro término o quita el filtro.';

  @override
  String get searchErrorTitle => 'No se pudo buscar';

  @override
  String playbackFailed(String error) {
    return 'No se pudo reproducir: $error';
  }

  @override
  String get nothingPlaying => 'Nada sonando';

  @override
  String get libraryLikes => 'Me gusta';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryHistory => 'Historial';

  @override
  String get libraryEmptyLikes => 'No has marcado ninguna canción';

  @override
  String get librarySongs => 'Canciones';

  @override
  String get libraryEmptySongs => 'Aún no has guardado nada en tu biblioteca';

  @override
  String get libraryEmptyPlaylists => 'No tienes playlists guardadas';

  @override
  String get libraryEmptyHistory => 'Todavía no has escuchado nada';

  @override
  String get libraryPlaylistEmpty => 'Esta playlist está vacía';

  @override
  String get librarySignedOutTitle => 'Inicia sesión para ver tu biblioteca';

  @override
  String get librarySignedOutBody =>
      'Tus me gusta, playlists e historial de YouTube Music.';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginPasteTitle => 'Pega tu cookie de sesión';

  @override
  String get loginStep1 =>
      'Abre music.youtube.com en el navegador del ordenador, con tu sesión ya iniciada.';

  @override
  String get loginStep2 => 'Pulsa F12 y ve a la pestaña Network (Red).';

  @override
  String get loginStep3 =>
      'Recarga la página y haz clic en cualquier petición de la lista.';

  @override
  String get loginStep4 =>
      'En Request Headers, copia el valor completo de Cookie.';

  @override
  String get loginStep5 => 'Pégalo aquí abajo.';

  @override
  String get loginSave => 'Guardar sesión';

  @override
  String get loginNoSapisid =>
      'No encuentro la cookie de sesión (SAPISID) en lo que pegaste. Asegúrate de copiar la cabecera Cookie completa.';

  @override
  String get loginStorageNote =>
      'Se guarda cifrada en este dispositivo y no se envía a ningún sitio salvo a YouTube. Para revocarla, cierra sesión en tu cuenta de Google desde cualquier navegador.';

  @override
  String get homeErrorTitle => 'No se pudo cargar el inicio';

  @override
  String get homeEmptyTitle => 'Todavía no hay nada';

  @override
  String get homeEmptyBody =>
      'YouTube Music no tiene nada que mostrar para este dispositivo ahora mismo.';

  @override
  String get loginUseDeviceAccount => 'Usar una cuenta del dispositivo';

  @override
  String get loginOr => 'o pégala a mano';

  @override
  String loginDeviceAccountFailed(String reason) {
    return 'No se pudo usar esa cuenta ($reason). Pega la cookie en su lugar.';
  }

  @override
  String get accountTooltip => 'Cuenta';

  @override
  String get accountAppearance => 'Apariencia';

  @override
  String get accountSignedOut => 'Sin sesión iniciada';

  @override
  String get accountSignedIn => 'Sesión iniciada';

  @override
  String get queueTitle => 'A continuación';

  @override
  String get queueEmpty => 'No hay nada en cola';

  @override
  String get queueTooltip => 'Cola';

  @override
  String get shuffleOn => 'Aleatorio activado';

  @override
  String get shuffleOff => 'Aleatorio desactivado';

  @override
  String get repeatOff => 'Sin repetición';

  @override
  String get repeatAll => 'Repetir la cola';

  @override
  String get repeatOne => 'Repetir la canción';

  @override
  String get queueRemoved => 'Quitada de la cola';

  @override
  String get undo => 'Deshacer';

  @override
  String get menuPlayNext => 'Reproducir a continuación';

  @override
  String get menuAddToQueue => 'Añadir a la cola';

  @override
  String get menuLike => 'Añadir a Me gusta';

  @override
  String get menuAddToPlaylist => 'Añadir a una playlist';

  @override
  String get menuShare => 'Compartir';

  @override
  String get artistSubscribe => 'Suscribirse';

  @override
  String get artistUnsubscribe => 'Cancelar suscripción';

  @override
  String get artistSubscribed => 'Te has suscrito';

  @override
  String get artistUnsubscribed => 'Suscripción cancelada';

  @override
  String get menuCopyLink => 'Copiar enlace';

  @override
  String get menuLinkCopied => 'Enlace copiado';

  @override
  String get menuLiked => 'Añadida a Me gusta';

  @override
  String get menuQueued => 'Añadida a la cola';

  @override
  String menuAddedTo(String playlist) {
    return 'Añadida a $playlist';
  }

  @override
  String menuFailed(String reason) {
    return 'No se pudo: $reason';
  }

  @override
  String get playlistNew => 'Nueva playlist';

  @override
  String get playlistNameHint => 'Nombre de la playlist';

  @override
  String get create => 'Crear';

  @override
  String get playlistPickTitle => 'Añadir a una playlist';

  @override
  String get play => 'Reproducir';

  @override
  String get repeat => 'Repetir';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get artistSongs => 'Canciones';

  @override
  String get menuGoArtist => 'Ir al artista';

  @override
  String get menuGoAlbum => 'Ir al álbum';

  @override
  String get menuRadio => 'Iniciar radio';

  @override
  String get menuRadioStarted => 'Radio iniciada';

  @override
  String get collectionSave => 'Guardar en la biblioteca';

  @override
  String get collectionRemove => 'Quitar de la biblioteca';

  @override
  String get collectionSaved => 'Guardada en tu biblioteca';

  @override
  String get collectionRemoved => 'Quitada de tu biblioteca';

  @override
  String collectionSyncFailed(String reason) {
    return 'Guardada aquí. No se le pudo avisar a YouTube: $reason';
  }

  @override
  String get collectionMore => 'Más opciones';

  @override
  String get collectionDownloadAll => 'Descargar todas las canciones';

  @override
  String collectionDownloading(int count) {
    return 'Descargando $count canciones';
  }

  @override
  String get librarySaved => 'Guardadas';

  @override
  String get libraryEmptySaved =>
      'Aún no guardas nada. El corazón de una playlist la deja aquí.';

  @override
  String get lyricsTitle => 'Letra';

  @override
  String get lyricsNone => 'No encontramos la letra de esta canción.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSound => 'Reproducción y sonido';

  @override
  String get settingsSoundBody =>
      'Continuar solo, velocidad, fundido, ecualizador';

  @override
  String get settingsStorageBody => 'Descargas, caché y lo que ocupan';

  @override
  String get settingsBackupBody => 'Copia diaria, escribir una, restaurar';

  @override
  String get settingsAppearanceBody => 'Tema, colores y las barras';

  @override
  String get settingsSystem => 'Sistema';

  @override
  String get settingsSystemBody =>
      'El widget de la pantalla de inicio y las actualizaciones';

  @override
  String get settingsPlayback => 'Reproducción';

  @override
  String get settingsAutoplay => 'Seguir sonando';

  @override
  String get settingsAutoplayBody =>
      'Cuando se acabe la cola, continuar con una radio de lo que estabas escuchando.';

  @override
  String get settingsSkipSilence => 'Saltar silencios';

  @override
  String get settingsSkipSilenceBody =>
      'Pasar por encima de los tramos mudos dentro de una canción.';

  @override
  String get settingsNormalize => 'Emparejar el volumen';

  @override
  String get settingsNormalizeBody =>
      'Levantar las grabaciones bajas para que una canción no llegue mucho más fuerte que la anterior.';

  @override
  String settingsSpeed(String value) {
    return 'Velocidad: $value×';
  }

  @override
  String get settingsEqualizer => 'Ecualizador';

  @override
  String get settingsEqualizerOn => 'Usar el ecualizador';

  @override
  String get settingsSleep => 'Temporizador de apagado';

  @override
  String settingsSleepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String settingsSleepPending(int minutes) {
    return 'Se detiene en $minutes min';
  }

  @override
  String get settingsEqualizerIdle =>
      'Pon algo a sonar para ajustar las bandas: Android solo abre el ecualizador cuando hay audio.';

  @override
  String get themeDynamic => 'Colores de la portada';

  @override
  String get appearanceBars => 'Barras del reproductor y la navegación';

  @override
  String get barSolid => 'Sólido';

  @override
  String get barSolidBody => 'Opaco, como ha sido siempre.';

  @override
  String get barGlass => 'Cristal esmerilado';

  @override
  String get barGlassBody =>
      'Se ve a través con el fondo desenfocado, así el texto sigue legible sobre cualquier portada.';

  @override
  String get barTranslucent => 'Translúcido';

  @override
  String get barTranslucentBody =>
      'Se ve a través sin desenfocar. Más barato, y más sucio sobre una portada con mucho detalle.';

  @override
  String get barClear => 'Transparente';

  @override
  String get barClearBody =>
      'Sin fondo ninguno. Sobre una portada clara el texto puede desaparecer.';

  @override
  String get themeDynamicBody =>
      'Repintar la app con los colores de la carátula que suena.';

  @override
  String get statsTitle => 'Lo que escuchas';

  @override
  String get statsWeek => 'Semana';

  @override
  String get statsMonth => 'Mes';

  @override
  String get statsYear => 'Año';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '1 reproducción',
      zero: 'Aún no hay reproducciones',
    );
    return '$_temp0';
  }

  @override
  String get statsEmpty => 'Pon algo a sonar y aparecerá aquí.';

  @override
  String get statsArtists => 'Artistas más escuchados';

  @override
  String get statsSongs => 'Canciones más escuchadas';

  @override
  String get accountStats => 'Lo que escuchas';

  @override
  String get navExplore => 'Explorar';

  @override
  String get exploreNew => 'Novedades';

  @override
  String get exploreCharts => 'Populares';

  @override
  String get exploreMoods => 'Ambientes';

  @override
  String get libraryDownloads => 'Descargas';

  @override
  String get libraryEmptyDownloads =>
      'Aún no hay descargas. Usa el menú de una canción para guardarla en este dispositivo.';

  @override
  String get menuDownload => 'Descargar';

  @override
  String get menuRemoveDownload => 'Quitar la descarga';

  @override
  String get menuDownloading => 'Descargando…';

  @override
  String get menuDownloaded => 'Guardada en este dispositivo';

  @override
  String get menuDownloadRemoved => 'Quitada de este dispositivo';

  @override
  String get settingsStorage => 'Almacenamiento';

  @override
  String get settingsCache => 'Guardar lo que suena';

  @override
  String get settingsCacheBody =>
      'Volver a oír una canción no gasta datos. Esto nunca toca las descargas.';

  @override
  String settingsCacheLimit(int mb) {
    return 'Límite de la caché: $mb MB';
  }

  @override
  String settingsCacheClear(String size) {
    return 'Vaciar la caché ($size)';
  }

  @override
  String get scrobbleTitle => 'Historial de escucha';

  @override
  String get scrobbleBody =>
      'YouTube no acepta lo que esta app le reporta de lo que escuchas. Estos servicios sí, y llevan veinte años guardando historiales.';

  @override
  String get scrobbleConnect => 'Conectar';

  @override
  String get scrobbleConnected => 'Conectado';

  @override
  String get scrobbleDisconnect => 'Desconectar';

  @override
  String get scrobbleTokenHint => 'Token de usuario';

  @override
  String get scrobbleLastFmBody =>
      'Last.fm entrega sus claves por aplicación, así que esta compilación necesita la tuya: créala en last.fm/api y luego autoriza la conexión.';

  @override
  String get scrobbleApproved => 'Ya autoricé';

  @override
  String get accountScrobble => 'Historial de escucha';

  @override
  String get settingsBackup => 'Copias de seguridad';

  @override
  String get settingsBackupAuto => 'Copia diaria';

  @override
  String get settingsBackupAutoBody =>
      'Escribir una copia del historial y los ajustes una vez al día, guardando las últimas cinco.';

  @override
  String get settingsBackupNow => 'Crear una copia ahora';

  @override
  String settingsBackupWritten(String path) {
    return 'Guardada en $path';
  }

  @override
  String get settingsBackupRestore => 'Restaurar una copia';

  @override
  String get settingsBackupRestored =>
      'Restaurada. Vuelve a abrir la app para verlo todo.';

  @override
  String get settingsBackupNone => 'Todavía no hay copias en este dispositivo.';

  @override
  String get menuUnlike => 'Quitar de Me gusta';

  @override
  String get menuUnliked => 'Quitada de Me gusta';

  @override
  String get menuRemoveFromLibrary => 'Quitar de la biblioteca';

  @override
  String get menuRemovedFromLibrary => 'Quitada de la biblioteca';

  @override
  String get menuRemoveFromHistory => 'Quitar del historial';

  @override
  String get menuRemovedFromHistory => 'Quitada del historial';

  @override
  String get menuPinToRecap => 'Fijar en Vuelve a escucharlo';

  @override
  String get menuUnpinFromRecap => 'Desfijar de Vuelve a escucharlo';

  @override
  String get menuPinned => 'Fijada en Vuelve a escucharlo';

  @override
  String get menuUnpinned => 'Desfijada de Vuelve a escucharlo';

  @override
  String get menuRemoveFromPlaylist => 'Quitar de la lista';

  @override
  String get menuRemovedFromPlaylist => 'Quitada de la lista';

  @override
  String get menuCredits => 'Ver créditos de la canción';

  @override
  String get creditsTitle => 'Créditos de la canción';

  @override
  String get creditsEmpty => 'YouTube no tiene créditos de esta canción';

  @override
  String get playlistRenamed => 'Nombre cambiado';

  @override
  String get playlistDeleted => 'Lista eliminada';

  @override
  String playlistDeleteConfirm(String name) {
    return '¿Eliminar “$name”? No se puede deshacer.';
  }

  @override
  String get searchRecent => 'Búsquedas recientes';

  @override
  String get searchRecentClear => 'Borrar';

  @override
  String get settingsStorageRefresh => 'Recalcular';

  @override
  String get settingsStorageCache => 'Caché';

  @override
  String get playbackControls => 'Controles de reproducción';

  @override
  String get sleepCustom => 'Personalizado';

  @override
  String get sleepRunning => 'La música se pausará';

  @override
  String get sleepStart => 'Iniciar';

  @override
  String get unitSeconds => 'seg';

  @override
  String get unitMinutes => 'min';

  @override
  String get unitHours => 'horas';

  @override
  String get tipMore => 'Más opciones';

  @override
  String get tipClear => 'Borrar';

  @override
  String get tipPrevious => 'Canción anterior';

  @override
  String get tipNext => 'Canción siguiente';

  @override
  String get tipPlay => 'Reproducir';

  @override
  String get tipPause => 'Pausar';

  @override
  String get tipRemove => 'Quitar';

  @override
  String get tipReorder => 'Arrastra para reordenar';

  @override
  String get sortNatural => 'Orden original';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortPlays => 'Más escuchadas';

  @override
  String get sortAscending => 'Ascendente';

  @override
  String get sortDescending => 'Descendente';

  @override
  String sortCount(int count) {
    return '$count canciones';
  }

  @override
  String get libraryAuto => 'Hechas para ti';

  @override
  String get autoTop => 'Tus 100 más';

  @override
  String get autoDownloads => 'Descargadas';

  @override
  String get autoCached => 'Listas sin conexión';

  @override
  String get playlistRename => 'Renombrar';

  @override
  String get playlistDelete => 'Eliminar';

  @override
  String get playlistEmptyLocal =>
      'Esta playlist está vacía. Añade canciones desde el menú de cualquier canción.';

  @override
  String get playlistLocalNew => 'Nueva playlist';

  @override
  String get playlistOnDevice => 'En este dispositivo';

  @override
  String get playlistInAccount => 'En tu cuenta';

  @override
  String get downloadQueued => 'En espera';

  @override
  String get settingsFade => 'Fundido entre canciones';

  @override
  String get settingsFadeBody =>
      'Entrar y salir suave en vez de cortar. Cero lo apaga.';

  @override
  String settingsFadeValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get libraryArtists => 'Artistas';

  @override
  String get libraryAlbums => 'Álbumes';

  @override
  String get libraryEmptyArtists => 'Aún no guardas artistas.';

  @override
  String get libraryEmptyAlbums => 'Aún no guardas álbumes.';

  @override
  String get playlistSuggestions => 'También te puede gustar';

  @override
  String get themePalette => 'Color base';

  @override
  String get lyricsShare => 'Compartir la letra';

  @override
  String get lyricsPickLines => 'Elige hasta cuatro versos.';

  @override
  String get lyricsCardReady => 'Listo para compartir.';

  @override
  String get settingsKeepAwake => 'Mantener la pantalla encendida';

  @override
  String get settingsKeepAwakeBody =>
      'Mientras el reproductor está abierto, para dejar el teléfono a la vista.';

  @override
  String get paletteBaseColour => 'Color base';

  @override
  String get paletteBackground => 'Fondo';

  @override
  String get paletteSecondColour => 'Segundo color';

  @override
  String get paletteAngle => 'Ángulo';

  @override
  String get paletteFlat => 'Plano';

  @override
  String get paletteLinear => 'Lineal';

  @override
  String get paletteRadial => 'Circular';

  @override
  String get paletteCustom => 'Personalizado';

  @override
  String get paletteHue => 'Tono';

  @override
  String get paletteSaturation => 'Saturación';

  @override
  String get paletteBrightness => 'Brillo';

  @override
  String get paletteReset => 'Volver al color de la app';

  @override
  String get themeCustomise => 'Personalizar';

  @override
  String get paletteGradientColours => 'Colores del degradado';

  @override
  String get paletteHoldToRemove => 'Toca para cambiar, mantén para quitar';

  @override
  String get libraryDevice => 'Del dispositivo';

  @override
  String get libraryDeviceEmpty =>
      'Aquí aparece la música guardada en este dispositivo.';

  @override
  String get libraryDeviceScan => 'Buscar música';

  @override
  String get libraryDeviceDenied =>
      'Sin acceso a tu audio no hay nada que revisar.';

  @override
  String get libraryDeviceFolders => 'Elegir carpetas…';

  @override
  String get settingsMusicFolders => 'Carpetas de música';

  @override
  String get settingsMusicFoldersBody =>
      'Dónde buscar música además de las carpetas de siempre.';

  @override
  String get musicFoldersBody =>
      'Música y Descargas ya se leen. Cualquier otra — Documentos, el escritorio, un disco externo — se elige aquí una vez y se recuerda.';

  @override
  String get musicFoldersAdd => 'Añadir carpeta…';

  @override
  String get musicFoldersEmpty => 'Todavía no hay carpetas añadidas.';

  @override
  String get musicFoldersRemove => 'Quitar';

  @override
  String get musicFoldersUnavailable => 'Ahora mismo no se puede llegar';

  @override
  String get settingsWidget => 'Añadir el widget a la pantalla de inicio';

  @override
  String get settingsWidgetBody =>
      'Lo que suena y sus controles, sin abrir la app.';

  @override
  String get settingsWidgetManual =>
      'A este lanzador no se le puede pedir; añádelo manteniendo pulsada la pantalla de inicio y eligiendo Widgets.';

  @override
  String get nightstandExit => 'Salir de la mesita';

  @override
  String get nightstandNothing => 'No suena nada';

  @override
  String get settingsNightstand => 'Mesita de noche';

  @override
  String get settingsNightstandBody =>
      'Un reloj y la carátula mientras el teléfono descansa junto a la cama';

  @override
  String get nightstandShows => 'Qué se ve';

  @override
  String get nightstandClock => 'Reloj';

  @override
  String get nightstandArt => 'Carátula';

  @override
  String get nightstandTrack => 'Título y artista';

  @override
  String get nightstandProgress => 'Progreso';

  @override
  String get nightstandControlsLabel => 'Controles';

  @override
  String get nightstandControlsAlways => 'Siempre';

  @override
  String get nightstandControlsOnTouch => 'Al tocar';

  @override
  String get nightstandControlsNever => 'Ocultos';

  @override
  String get nightstandControlsBody =>
      'Ocultos significa que cualquier toque sale al reproductor.';

  @override
  String get nightstandScreenLabel => 'Pantalla';

  @override
  String nightstandDim(int percent) {
    return 'Brillo: $percent %';
  }

  @override
  String get nightstandBurnIn => 'Mover el contenido';

  @override
  String get nightstandBurnInBody =>
      'Desplaza todo unos píxeles cada minuto, para que una pantalla quieta no marque un OLED.';

  @override
  String get nightstandEnters => 'Entrar solo';

  @override
  String get nightstandIdle => 'Tras no hacer nada';

  @override
  String get nightstandIdleNever => 'Nunca';

  @override
  String nightstandIdleSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String nightstandIdleMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get nightstandIdleBody => 'Con el reproductor abierto y algo sonando.';

  @override
  String get nightstandOnCharge => 'Al empezar a cargar';

  @override
  String get nightstandOnChargeBody =>
      'Con algo sonando y el teléfono enchufado.';

  @override
  String get nightstandOpen => 'Modo mesita de noche';

  @override
  String get settingsUpdateNow => 'Buscar ahora';

  @override
  String get settingsUpdates => 'Actualizaciones';

  @override
  String settingsUpdatesInstalled(String version) {
    return 'Versión $version instalada';
  }

  @override
  String get settingsUpdateCheck => 'Buscar actualizaciones solo';

  @override
  String get settingsUpdateCheckBody =>
      'Una vez al día. Solo avisa cuando hay una versión nueva.';

  @override
  String get updateTitle => 'Hay una versión nueva';

  @override
  String updateSubtitle(String version, String size) {
    return 'Versión $version · $size MB';
  }

  @override
  String get updateNotes => 'Novedades';

  @override
  String get updateDownload => 'Descargar';

  @override
  String get updateInstall => 'Instalar';

  @override
  String get updateDownloading => 'Descargando…';

  @override
  String get updateChecking => 'Buscando…';

  @override
  String get updateUpToDate => 'Ya tienes la última versión.';

  @override
  String get updateFailed =>
      'No se ha podido consultar GitHub. Inténtalo más tarde.';

  @override
  String get updatePermission =>
      'Hay que decirle a Android que Tunebox puede instalar aplicaciones.';

  @override
  String get updatePermissionOpen => 'Abrir ajustes';

  @override
  String get updateSignature =>
      'El archivo que ha llegado no está firmado por Tunebox. Se ha descartado y no se ha instalado nada.';
}
