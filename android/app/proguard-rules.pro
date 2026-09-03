# Google Mobile Ads incorpora WorkManager, que guarda su estado con Room.
# Room instancia clases generadas como WorkDatabase_Impl por reflexión; R8 no
# ve esa referencia y puede renombrarlas, provocando un crash antes de que
# Flutter ejecute main().
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-keep class * extends androidx.work.ListenableWorker { public <init>(...); }

-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-keep @androidx.room.Database class * { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class **_Impl { *; }
