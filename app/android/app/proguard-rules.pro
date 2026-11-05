# MediaPipe Tasks uses reflection and JNI.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.proto.**
-dontwarn com.google.auto.value.**
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**
# CameraX
-keep class androidx.camera.** { *; }
# The pose bridge plugin
-keep class app.motionquest.pose_bridge.** { *; }
