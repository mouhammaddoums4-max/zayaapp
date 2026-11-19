# Règles R8 de la version release (ajoutées automatiquement par le plugin Gradle de Flutter).
#
# WorkManager (embarqué par la publicité Google, play-services-ads) crée sa base Room par réflexion
# (WorkDatabase_Impl). Sans ces règles, R8 retire le constructeur et l'application se ferme dès le démarrage :
# « Failed to create an instance of androidx.work.impl.WorkDatabase » (InitializationProvider), le 18/11/2026.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
