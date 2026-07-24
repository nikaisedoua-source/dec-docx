package org.dndocx.app

import android.os.Bundle
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        clearPreviousVersionData()
        super.onCreate(savedInstanceState)
    }

    private fun clearPreviousVersionData() {
        val updatePreferences = getSharedPreferences(UPDATE_PREFERENCES, MODE_PRIVATE)
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val installedVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
        val previousVersion = updatePreferences.getLong(VERSION_KEY, -1L)

        if (previousVersion == installedVersion) {
            return
        }

        val applicationData = File(applicationInfo.dataDir)
        applicationData.listFiles()?.forEach { directory ->
            if (directory.name == "shared_prefs") {
                directory.listFiles()?.forEach { preferenceFile ->
                    if (preferenceFile.name != "$UPDATE_PREFERENCES.xml") {
                        preferenceFile.deleteRecursively()
                    }
                }
            } else if (directory.name in DATA_DIRECTORIES_TO_CLEAR) {
                directory.deleteRecursively()
            }
        }

        updatePreferences.edit().putLong(VERSION_KEY, installedVersion).commit()
    }

    companion object {
        private const val UPDATE_PREFERENCES = "dec_docx_update_state"
        private const val VERSION_KEY = "installed_version_code"
        private val DATA_DIRECTORIES_TO_CLEAR = setOf(
            "app_flutter",
            "app_webview",
            "cache",
            "code_cache",
            "databases",
            "files",
            "no_backup",
        )
    }
}
