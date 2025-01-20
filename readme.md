# Instalación Manual de Compute-Subnet

## Descripción
Este proyecto contiene un **script de instalación** que, al ejecutarse, se encarga de:
* **Clonar** automáticamente el repositorio de Compute-Subnet.
* **Instalar** Docker, NVIDIA drivers (si no detecta CUDA), PM2, Bittensor, y otras dependencias necesarias.
* **Configurar** Python, entornos virtuales, y librerías de OpenCL.

## Requisitos Previos
* Python 3.10 y python3.10-venv instalados en el sistema
* Acceso root o permisos de sudo
* Conexión a internet estable
* Clave WANDB generada desde wandb.ai

## Pasos para la Instalación

1. **Ejecuta el script de instalación**
   * El script mostrará los componentes a instalar
   * Solicitará confirmación para:
     - Configuración de UFW (puertos)
     - Incremento de `ulimit`
   * Se instalarán automáticamente:
     - Docker
     - CUDA (si no está presente)
     - Otras herramientas necesarias

2. **Configuración de WANDB**
   ```bash
   cd Compute-Subnet
   cp .env.example .env
   ```
   * Edita el archivo `.env` para configurar:
     - WANDB_KEY (requerida para el funcionamiento)
     - Otras variables de entorno necesarias

3. **Creación de Wallet Bittensor**
   ```bash
   btcli new_coldkey
   btcli new_hotkey
   ```
   Este paso es necesario para la interacción con la red Bittensor.

## Detalles de Instalación
* El script clona `Compute-Subnet` automáticamente
* UFW configurará los rangos de puertos especificados
* Se instalarán todas las dependencias de Python necesarias

## Verificación Post-Instalación

1. **Verifica Docker y CUDA:**
   ```bash
   docker --version
   nvidia-smi
   ```

2. **Confirma las dependencias de Python:**
   ```bash
   cd Compute-Subnet
   pip list
   ```

3. **Revisa la configuración:**
   * Archivo `.env` completo con WANDB_KEY
   * Wallet de Bittensor creada y configurada
   * Puertos UFW abiertos según especificaciones

## Resolución de Problemas

### Docker
* Verifica que los repositorios se añadieron correctamente
* Confirma que el servicio está activo: `systemctl status docker`

### NVIDIA Drivers
* Asegura compatibilidad con tu distribución
* Verifica logs en `/var/log/nvidia-installer.log`

### Bittensor
* Confirma la existencia de las claves en `~/.bittensor/wallets/`
* Verifica la conexión a la red: `btcli status`

## Documentación Adicional
* Bittensor: [bittensor.com/documentation](https://bittensor.com/documentation)
* Compute-Subnet: [GitHub Repository](https://github.com/opentensor/compute-subnet)
* WANDB: [wandb.ai/guides](https://wandb.ai/guides)