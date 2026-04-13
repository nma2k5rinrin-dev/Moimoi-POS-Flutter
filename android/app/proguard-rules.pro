# Proguard rules for Flutter and Drift
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Drift & SQLCipher
-keep class com.tekartik.sqflite.** { *; }
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# SharedPreferences and Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
-dontwarn com.tekartik.sqflite.**
-dontwarn net.sqlcipher.**
-dontwarn es.antonborri.home_widget.**
-dontwarn app.web.groons.print_bluetooth_thermal.**

# FreeRASP / Talsec
-keep class com.aheaditec.talsec_security.** { *; }
-dontwarn com.aheaditec.talsec_security.**
-keep class com.freerasp.** { *; }
-dontwarn com.freerasp.**
