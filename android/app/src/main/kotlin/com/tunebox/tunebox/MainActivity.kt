package com.tunebox.tunebox

import com.ryanheise.audioservice.AudioServiceActivity

// Must extend AudioServiceActivity rather than FlutterActivity so the media
// session can rebind to the UI when the app is reopened from the notification.
class MainActivity : AudioServiceActivity()
