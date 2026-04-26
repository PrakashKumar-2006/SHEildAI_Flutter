# Preserve Vosk classes required by Native C++ (JNI)
-keep class org.vosk.** { *; }

# Preserve JNA classes (used by Vosk under the hood)
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
-dontwarn java.awt.**
-dontwarn com.sun.jna.**
