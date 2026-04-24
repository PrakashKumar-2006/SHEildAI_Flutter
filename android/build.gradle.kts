import org.gradle.api.Action

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
subprojects {
    val project = this
    if (project.name == "sms_advanced" || project.name == "telephony") {
        val action = Action<Project> {
            val android = extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                if (android.namespace == null) {
                    android.namespace = group.toString()
                    if (android.namespace == "") {
                        android.namespace = "com.github.clans.sms_advanced"
                    }
                }
            }
        }
        if (project.state.executed) {
            action.execute(project)
        } else {
            project.afterEvaluate(action)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
