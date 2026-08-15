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
  String get lyricsTitle => 'Letra';

  @override
  String get lyricsNone => 'No encontramos la letra de esta canción.';

  @override
  String get settingsTitle => 'Ajustes';

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
  String get accountSettings => 'Reproducción y sonido';

  @override
  String get settingsEqualizerIdle =>
      'Pon algo a sonar para ajustar las bandas: Android solo abre el ecualizador cuando hay audio.';

  @override
  String get themeDynamic => 'Colores de la portada';

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
}
