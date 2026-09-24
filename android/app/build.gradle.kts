import java.util.Properties
import java.io.FileInputStream

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

android {
    namespace = "br.com.clubbar.cliente"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
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
                "Clubbar"
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

    applicationVariants.all {
        val flavor = flavorName
        val build = buildType.name
        val apkName = "clubbar-$flavor-$build.apk"

        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = apkName
        }

        assembleProvider.configure {
            doLast {
                val sourceApk = layout.buildDirectory
                    .file("outputs/apk/$flavor/$build/$apkName")
                    .get()
                    .asFile
                val flutterOutputDir = layout.buildDirectory
                    .dir("outputs/flutter-apk")
                    .get()
                    .asFile

                flutterOutputDir.mkdirs()
                sourceApk.copyTo(flutterOutputDir.resolve(apkName), overwrite = true)
            }
        }
    }
}

flutter {
    source = "../.."
}
