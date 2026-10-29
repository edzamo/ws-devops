# Minikube

Bienvenido al curso de Minikube. En este curso aprenderás a desplegar y gestionar clústeres de Kubernetes de manera local utilizando Minikube.

## ¿Qué es Minikube?

Minikube es una herramienta que permite ejecutar un clúster de Kubernetes localmente en tu máquina. Es ideal para aprender, desarrollar y probar aplicaciones en Kubernetes sin necesidad de utilizar recursos en la nube.

## Instalación

### macOS

1. Instala Homebrew si no lo tienes:
    ```sh
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
2. Instala Minikube:
    ```sh
    brew install minikube
    ```
3. Inicia Minikube:
    ```sh
    minikube start
    ```

### Linux

1. Descarga el binario de Minikube:
    ```sh
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    ```
2. Instala Minikube:
    ```sh
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    ```
3. Inicia Minikube:
    ```sh
    minikube start
    ```

¡Listo! Ya puedes comenzar a trabajar con Kubernetes en tu entorno local.