# --- ML KIT KEEP RULES ---
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Optional for text languages
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# --- HMS PUSH / ANALYTICS KEEP RULES ---
-keep class com.huawei.** { *; }
-dontwarn com.huawei.**

# Prevent removing BuildEx (Huawei OS version class)
-keep class com.huawei.android.os.BuildEx { *; }

# --- Firebase (if you use FCM also) ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
