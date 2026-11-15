import java.util.Properties
import java.io.FileInputStream
import com.android.build.api.dsl.ApplicationExtension
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val signingFields = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
if (releaseRequested && signingFields.any { keystoreProperties.getProperty(it).isNullOrBlank() }) {
    error("Assinatura de produção ausente: configure android/key.properties antes de gerar o AAB/APK release.")
}

extensions.configure<ApplicationExtension> {
    namespace = "br.com.clubbar.cliente"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "br.com.clubbar.cliente"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"

            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"

            resValue(
                "string",
                "app_name",
                "Clubbar Client Dev"
            )
        }

        create("prod") {
            dimension = "environment"

            resValue(
                "string",
                "app_name",
                "Clubbar"
            )
        }
    }
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            keystoreProperties.getProperty("storeFile")?.let { storeFile = file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
