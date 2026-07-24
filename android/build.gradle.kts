allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some Flutter plugins (e.g. `alarm` 5.5.0) pin an older `compileSdk` than their
// own transitive dependencies need (flutter_fgbg is built against API 35+). Force
// every Android module to compile against API 36 so the AAR-metadata checks pass.
// Reflection keeps this AGP-version-agnostic; the `state.executed` guard avoids
// calling afterEvaluate on `:app`, which is evaluated early by the block below.
subprojects {
    val setCompileSdk = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType!!)
                    .invoke(androidExt, 36)
            } catch (e: Exception) {
                logger.warn("compileSdk override skipped for $name: ${e.message}")
            }
        }
    }
    if (state.executed) setCompileSdk() else afterEvaluate { setCompileSdk() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
