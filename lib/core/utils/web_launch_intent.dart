enum WebLaunchIntent { mushaf, videoStudio }

WebLaunchIntent resolveWebLaunchIntent(Uri uri) {
  return uri.queryParameters['open'] == 'video-studio'
      ? WebLaunchIntent.videoStudio
      : WebLaunchIntent.mushaf;
}
