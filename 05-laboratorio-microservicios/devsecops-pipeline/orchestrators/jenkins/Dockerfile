# Jenkins con lo mínimo para correr el pipeline: Java 21 (ya viene), Maven, Python, el CLI de Docker
# (usa el Docker del host vía socket) y los plugins. El resto de herramientas corre en contenedores.
FROM jenkins/jenkins:2.580.2-lts-jdk21

USER root
RUN apt-get update && apt-get install -y --no-install-recommends maven python3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=docker:29-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:29-cli /usr/local/libexec/docker/cli-plugins/ /usr/local/libexec/docker/cli-plugins/
USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Sin asistente de instalación: todo se configura desde casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/var/jenkins_conf/casc.yaml
COPY casc.yaml /var/jenkins_conf/casc.yaml
