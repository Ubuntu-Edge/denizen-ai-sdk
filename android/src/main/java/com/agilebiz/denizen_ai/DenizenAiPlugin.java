package com.agilebiz.denizen_ai;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/** DenizenAiPlugin */
public class DenizenAiPlugin implements FlutterPlugin {
  static {
    try {
      System.loadLibrary("sqlite_vec");
    } catch (Throwable e) {
      android.util.Log.w("DenizenAiPlugin", "Failed to load sqlite_vec: " + e.getMessage());
    }
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
  }
}
