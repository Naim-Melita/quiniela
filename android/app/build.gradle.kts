import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciales de firma de release.
//
// Viven en android/key.properties, que esta en .gitignore junto con los .jks:
// el keystore y sus contrasenas no van al repositorio nunca. Ver
// key.properties.example para el formato.
val propiedadesDeFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) {
        FileInputStream(archivo).use { load(it) }
    }
}
val hayFirmaPropia = propiedadesDeFirma.getProperty("storeFile") != null

android {
    namespace = "com.armelix.quiniela"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.armelix.quiniela"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("release") {
                // Las rutas de key.properties se resuelven desde android/, asi
                // que sirve tanto "upload-keystore.jks" como una ruta absoluta.
                storeFile = rootProject.file(propiedadesDeFirma.getProperty("storeFile"))
                storePassword = propiedadesDeFirma.getProperty("storePassword")
                keyAlias = propiedadesDeFirma.getProperty("keyAlias")
                keyPassword = propiedadesDeFirma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sin key.properties el artefacto sale SIN FIRMAR a proposito.
            //
            // Antes caia en la clave de debug, que compila y parece que anda
            // pero Play rechaza en la subida. Un artefacto sin firmar falla
            // antes y de forma evidente, en vez de hacerte perder el viaje.
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

// Sin credenciales, la build de release se corta.
//
// Se corta en vez de avisar porque `flutter build` filtra los warning de Gradle:
// el aviso nunca llegaba a verse y el resultado era un artefacto sin firmar, que
// no sirve para nada y recien lo rechaza Play despues de subirlo. Las builds de
// debug no se tocan.
if (!hayFirmaPropia) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") }) {
            throw GradleException(
                "\n\nFalta android/key.properties: la build de release saldria " +
                    "sin firmar y Play la rechaza.\n" +
                    "Copiar android/key.properties.example a " +
                    "android/key.properties y completarlo.\n"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
