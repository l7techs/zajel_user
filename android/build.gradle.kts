allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// CUSTOM-START: AGP 9 checks AAR metadata on plugin modules too — old plugins (e.g. flutter_keyboard_visibility,
// compileSdk 31) fail checkAarMetadata against newer androidx deps. Raise their compileSdk to at least 36.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
            if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
        }
    }
}
// CUSTOM-END

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
