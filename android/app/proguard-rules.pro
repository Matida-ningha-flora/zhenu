# Règles de compactage (R8) pour la version release.
#
# MediaPipe charge ses classes depuis le code natif et lit ses options via
# protobuf : si R8 les renomme ou les supprime, la création du détecteur
# plante. On les conserve telles quelles.
-keep class com.google.mediapipe.** { *; }
-keep interface com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Dépendances optionnelles référencées par MediaPipe mais absentes sur Android.
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**
-dontwarn autovalue.shaded.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
