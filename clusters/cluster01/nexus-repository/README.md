# Nexus Repository Manager OSS

Sonatype Nexus Repository Manager OSS deployed to cluster01 for managing Java artifacts (Maven, Gradle, Ant) and other package formats.

## Deployment Details

- **Namespace:** `nexus-repository`
- **Storage:** 50Gi persistent volume (RWO) using `lvms-vg1` storage class
- **Resources:**
  - CPU: 500m requests / 2 cores limit
  - Memory: 2Gi requests / 4Gi limit
- **Image:** `docker.io/sonatype/nexus3:3.71.0`
- **Access URL:** https://nexus-nexus-repository.apps.co1.skumars.net

## Initial Setup

### First Login

1. Navigate to https://nexus-nexus-repository.apps.co1.skumars.net
2. Click "Sign In" in the upper right
3. Login with:
   - **Username:** `admin`
   - **Initial Password:** Retrieved from pod with:
     ```bash
     oc exec -n nexus-repository deployment/nexus -- cat /nexus-data/admin.password
     ```
4. Complete the setup wizard and change the admin password
5. Enable or disable anonymous access as needed

### Configure Maven Repositories

After first login, the default repositories include:
- `maven-central`: Proxy to Maven Central (https://repo1.maven.org/maven2/)
- `maven-releases`: Hosted repository for release artifacts
- `maven-snapshots`: Hosted repository for snapshot artifacts
- `maven-public`: Group repository combining all Maven repositories

## Maven Configuration

### Option 1: Global Settings (~/.m2/settings.xml)

Configure Maven to use Nexus as a mirror for all repositories:

```xml
<settings>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-public/</url>
    </mirror>
  </mirrors>

  <!-- Optional: Authentication for deployment -->
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>admin</username>
      <password>YOUR_PASSWORD</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>admin</username>
      <password>YOUR_PASSWORD</password>
    </server>
  </servers>
</settings>
```

### Option 2: Project pom.xml

Add repository configuration directly to your project:

```xml
<project>
  <!-- ... -->
  
  <repositories>
    <repository>
      <id>nexus</id>
      <name>Nexus Repository</name>
      <url>https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-public/</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>

  <distributionManagement>
    <repository>
      <id>nexus-releases</id>
      <name>Nexus Release Repository</name>
      <url>https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
      <id>nexus-snapshots</id>
      <name>Nexus Snapshot Repository</name>
      <url>https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-snapshots/</url>
    </snapshotRepository>
  </distributionManagement>
</project>
```

### Deploy Artifacts to Nexus

```bash
mvn clean deploy
```

## Gradle Configuration

### Gradle Groovy DSL (build.gradle)

```groovy
repositories {
    maven {
        url "https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-public/"
        allowInsecureProtocol = false
    }
}

publishing {
    publications {
        maven(MavenPublication) {
            from components.java
        }
    }
    repositories {
        maven {
            name = "nexus"
            def releasesRepoUrl = "https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-releases/"
            def snapshotsRepoUrl = "https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-snapshots/"
            url = version.endsWith('SNAPSHOT') ? snapshotsRepoUrl : releasesRepoUrl
            credentials {
                username = project.findProperty("nexusUsername") ?: "admin"
                password = project.findProperty("nexusPassword") ?: ""
            }
        }
    }
}
```

### Gradle Kotlin DSL (build.gradle.kts)

```kotlin
repositories {
    maven {
        url = uri("https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-public/")
        isAllowInsecureProtocol = false
    }
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }
    repositories {
        maven {
            name = "nexus"
            val releasesRepoUrl = uri("https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-releases/")
            val snapshotsRepoUrl = uri("https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-snapshots/")
            url = if (version.toString().endsWith("SNAPSHOT")) snapshotsRepoUrl else releasesRepoUrl
            credentials {
                username = project.findProperty("nexusUsername")?.toString() ?: "admin"
                password = project.findProperty("nexusPassword")?.toString() ?: ""
            }
        }
    }
}
```

### Gradle Credentials (~/.gradle/gradle.properties)

Store credentials securely:

```properties
nexusUsername=admin
nexusPassword=YOUR_PASSWORD
```

### Publish Artifacts to Nexus

```bash
./gradlew publish
```

## Ant Configuration

### Using ivy.xml

```xml
<ivy-module version="2.0">
  <info organisation="com.example" module="my-app"/>
  
  <configurations>
    <conf name="default"/>
  </configurations>
  
  <dependencies>
    <dependency org="org.apache.commons" name="commons-lang3" rev="3.12.0" conf="default"/>
  </dependencies>
</ivy-module>
```

### ivysettings.xml

```xml
<ivysettings>
  <settings defaultResolver="nexus"/>
  <resolvers>
    <ibiblio name="nexus" m2compatible="true" 
             root="https://nexus-nexus-repository.apps.co1.skumars.net/repository/maven-public/"/>
  </resolvers>
</ivysettings>
```

### build.xml

```xml
<project name="MyProject" default="resolve" xmlns:ivy="antlib:org.apache.ivy.ant">
  
  <target name="resolve">
    <ivy:retrieve pattern="lib/[artifact]-[revision].[ext]"/>
  </target>
  
</project>
```

## Docker Registry (Ports 8082, 8083)

Nexus also provides Docker registry capabilities:
- **Port 8082:** Docker hosted registry (push your images)
- **Port 8083:** Docker proxy registry (proxy to Docker Hub)

To use, create additional routes or configure registry in Nexus UI.

## Monitoring and Management

### Check Pod Status

```bash
oc get pods -n nexus-repository
```

### View Logs

```bash
oc logs -f deployment/nexus -n nexus-repository
```

### Check Storage Usage

```bash
oc get pvc -n nexus-repository
oc exec -n nexus-repository deployment/nexus -- df -h /nexus-data
```

### Access Nexus Container

```bash
oc exec -it deployment/nexus -n nexus-repository -- /bin/bash
```

## Backup and Restore

### Backup Nexus Data

```bash
# Create a backup of nexus-data PVC
oc exec -n nexus-repository deployment/nexus -- tar czf /tmp/nexus-backup.tar.gz /nexus-data
oc cp nexus-repository/nexus-859649dc4c-xxxxx:/tmp/nexus-backup.tar.gz ./nexus-backup.tar.gz
```

### Restore from Backup

```bash
# Copy backup to pod and extract
oc cp ./nexus-backup.tar.gz nexus-repository/nexus-859649dc4c-xxxxx:/tmp/
oc exec -n nexus-repository deployment/nexus -- tar xzf /tmp/nexus-backup.tar.gz -C /
oc rollout restart deployment/nexus -n nexus-repository
```

## Troubleshooting

### Pod Not Starting

```bash
oc describe pod -n nexus-repository -l app=nexus
oc logs -n nexus-repository -l app=nexus
```

### PVC Not Binding

```bash
oc get pvc -n nexus-repository
oc describe pvc nexus-data -n nexus-repository
```

### Out of Memory

If Nexus runs out of memory, adjust JVM settings in [02-deployment.yaml](02-deployment.yaml):
```yaml
env:
- name: INSTALL4J_ADD_VM_PARAMS
  value: "-Xms2048m -Xmx2048m -XX:MaxDirectMemorySize=3g"
```

## Upgrading Nexus

To upgrade to a newer version, update the image tag in [02-deployment.yaml](02-deployment.yaml):
```yaml
image: docker.io/sonatype/nexus3:3.72.0  # Update version here
```

Commit and push the change - ArgoCD will sync automatically.

## Resources

- [Nexus Repository Manager Documentation](https://help.sonatype.com/repomanager3)
- [Maven Configuration Guide](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/maven-repositories)
- [Gradle Configuration Guide](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/maven-repositories#MavenRepositories-Gradle)
