# Reglas de R8 para la versión de Google Play.
# flutter_local_notifications guarda los recordatorios programados con Gson (necesita los tipos genéricos).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# Canal nativo de AirPods (W2W).
-keep class dev.huergalabs.word_to_word.** { *; }
