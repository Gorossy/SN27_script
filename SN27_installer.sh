#!/bin/bash
set -u

# Enable command completion
set -o history -o histexpand

python="python3"

abort() {
  printf "%s\n" "$1"
  exit 1
}

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

# Minimal logger
ohai() {
  echo "==> $*"
}

################################################################################
# PRE-INSTALL
################################################################################
linux_install_pre() {
    sudo apt-get update
    sudo apt-get install --no-install-recommends --no-install-suggests -y apt-utils curl git cmake build-essential ca-certificates

    # Add Docker's official GPG key:
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker's repository:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    exit_on_error $? "docker-installation"
}

################################################################################
# SETUP VENV
################################################################################
linux_setup_venv() {
    ohai "Installing python3.10-venv (if not present)"
    sudo apt-get install -y python3.10-venv

    ohai "Creating Python venv in /home/ubuntu/venv"
    # Create the venv as the ubuntu user
    sudo -u ubuntu -H python3 -m venv /home/ubuntu/venv
    exit_on_error $? "venv-creation"

    # Upgrade pip inside the venv
    ohai "Upgrading pip in the new venv"
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install --upgrade pip
    exit_on_error $? "venv-pip-upgrade"

    # Option: Automatically activate the venv in ~/.bashrc
    echo "source /home/ubuntu/venv/bin/activate" | sudo tee -a /home/ubuntu/.bashrc
    sudo chown ubuntu:ubuntu /home/ubuntu/.bashrc
}

################################################################################
# COMPUTE-SUBNET
################################################################################
linux_install_compute_subnet() {
    ohai "Cloning or updating Compute-Subnet into /home/ubuntu/Compute-Subnet"
    sudo mkdir -p /home/ubuntu/Compute-Subnet

    if [ ! -d /home/ubuntu/Compute-Subnet/.git ]; then
      # Si no está clonado, clonamos
      sudo git clone https://github.com/neuralinternet/Compute-Subnet.git /home/ubuntu/Compute-Subnet/
    else
      # Si ya está, hacemos pull
      cd /home/ubuntu/Compute-Subnet
      sudo git pull --ff-only
    fi

    # Aseguramos que “ubuntu” sea el dueño de la carpeta
    sudo chown -R ubuntu:ubuntu /home/ubuntu/Compute-Subnet

    ohai "Installing Compute-Subnet dependencies (including correct Bittensor version)"
    cd /home/ubuntu/Compute-Subnet

    # Instalar dentro del venv
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install -r requirements.txt
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install --no-deps -r requirements-compute.txt

    # Instalación editable de Compute-Subnet
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install -e .
    exit_on_error $? "compute-subnet-installation"

    # Instalar librerías extra para OpenCL
    sudo apt -y install ocl-icd-libopencl1 pocl-opencl-icd

    ohai "Starting Docker service, adding user to docker, installing 'at' package"
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker ubuntu
    sudo systemctl start docker
    sudo apt install -y at

    cd /home/ubuntu
}

################################################################################
# PYTHON
################################################################################
linux_install_python() {
    if ! command -v "$python" >/dev/null 2>&1; then
        ohai "Installing python"
        sudo apt-get install --no-install-recommends --no-install-suggests -y "$python"
    else
        ohai "Upgrading python"
        sudo apt-get install --only-upgrade "$python"
    fi
    exit_on_error $? "python-install"

    ohai "Installing python dev tools"
    sudo apt-get install --no-install-recommends --no-install-suggests -y \
      "${python}-pip" "${python}-dev"
    exit_on_error $? "python-dev"
}

linux_update_pip() {
    ohai "Upgrading pip (system-wide)"
    "$python" -m pip install --upgrade pip
    exit_on_error $? "pip-upgrade"
}

################################################################################
# PM2
################################################################################
linux_install_pm2() {
    sudo apt-get update
    sudo apt-get install -y npm
    sudo npm install pm2 -g
}

################################################################################
# NVIDIA DOCKER
################################################################################
linux_install_nvidia_docker() {
    ohai "Installing NVIDIA Docker support"
    local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)

    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list \
      | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

    sudo apt-get update -y
    sudo apt-get install -y nvidia-container-toolkit nvidia-docker2

    ohai "NVIDIA Docker installed"
}

################################################################################
# CUDA INSTALLATION (NO removal of existing drivers)
################################################################################
linux_install_nvidia_cuda() {
    ohai "Checking if CUDA is already installed"
    # Revisamos si ya existe 'nvcc' o 'nvidia-smi'; si es así, asumimos que ya está configurado
    if command -v nvidia-smi >/dev/null 2>&1 || command -v nvcc >/dev/null 2>&1; then
        ohai "CUDA/NVIDIA drivers found; skipping re-installation."
        return
    fi

    ohai "CUDA/NVIDIA drivers not found. Proceeding with a fresh installation."

    ohai "Installing build essentials"
    sudo apt-get install -y build-essential dkms linux-headers-$(uname -r)

    ohai "Installing CUDA"
    wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb \
      -O /tmp/cuda-repo.deb
    sudo dpkg -i /tmp/cuda-repo.deb
    sudo cp /var/cuda-repo-ubuntu2204-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-12-3
    sudo apt-get -y install cuda-drivers

    ohai "Configuring environment variables"
    export CUDA_VERSION="cuda-12.3"
    {
      echo ""
      echo "# Added by NVIDIA CUDA install script"
      echo "export CUDA_VERSION=${CUDA_VERSION}"
      echo "export PATH=\$PATH:/usr/local/\$CUDA_VERSION/bin"
      echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/\$CUDA_VERSION/lib64"
    } >> /home/ubuntu/.bashrc

    # Ajustamos permisos y cargamos en la sesión actual
    sudo chown ubuntu:ubuntu /home/ubuntu/.bashrc
    source /home/ubuntu/.bashrc

    ohai "CUDA (Toolkit + Drivers) installation complete"
}

################################################################################
# UFW (DEFAULT PORT RANGE)
################################################################################
linux_install_ufw() {
    sudo apt-get update
    sudo apt-get install -y ufw
    sudo ufw allow 22/tcp
    sudo ufw allow 4444

    ohai "Enabling UFW and allowing ports 2000-5000"
    sudo ufw allow 2000:5000/tcp
    sudo ufw enable
}

################################################################################
# ULIMIT (ALWAYS INCREASE)
################################################################################
linux_increase_ulimit(){
    ohai "Increasing ulimit to 1,000,000"
    prlimit --pid=$PPID --nofile=1000000
}

################################################################################
# MAIN INSTALL
################################################################################
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then

    # Verificamos si apt está disponible
    if ! command -v apt >/dev/null 2>&1; then
        abort "This Linux-based install requires apt. For other distros, install requirements manually."
    fi

    echo """
    
 ░▒▓███████▓▒░ ░▒▓███████▓▒░        ░▒▓███████▓▒░  ░▒▓████████▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░        ░▒▓█▓▒░ 
 ░▒▓██████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░        ░▒▓██████▓▒░        ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░              ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░             ░▒▓█▓▒░   
░▒▓███████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓████████▓▒░      ░▒▓█▓▒░   
                                                                                                                                                             
                                                   - Bittensor; Mining a new element.
    """
    ohai "Starting auto-install..."
    linux_install_pre

    # Step 1: Install python, pip
    linux_install_python
    linux_update_pip

    # Step 2: Create and configure venv in /home/ubuntu/venv
    linux_setup_venv

    # Step 3: Install Compute-Subnet and Bittensor inside the venv
    linux_install_compute_subnet

    # PM2 (NodeJS)
    linux_install_pm2

    # NVIDIA docker
    linux_install_nvidia_docker

    # CUDA (without removing existing drivers)
    linux_install_nvidia_cuda

    # UFW
    linux_install_ufw

    # ulimit
    linux_increase_ulimit

    echo ""
    echo ""
    echo ""
    echo ""
    echo """
    
██████╗░██╗████████╗████████╗███████╗███╗░░██╗░██████╗░█████╗░██████╗░
██╔══██╗██║╚══██╔══╝╚══██╔══╝██╔════╝████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░█████╗░░██╔██╗██║╚█████╗░██║░░██║██████╔╝
██╔══██╗██║░░░██║░░░░░░██║░░░██╔══╝░░██║╚████║░╚═══██╗██║░░██║██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░███████╗██║░╚███║██████╔╝╚█████╔╝██║░░██║
╚═════╝░╚═╝░░░╚═╝░░░░░░╚═╝░░░╚══════╝╚═╝░░╚══╝╚═════╝░░╚════╝░╚═╝░░╚═╝
                                                    
                                                    - Mining a new element.
    """
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##                      BITTENSOR SETUP                             ##"
    echo "##                                                                  ##"
    echo "######################################################################"

elif [[ "$OS" == "Darwin" ]]; then
    abort "macOS installation is not implemented in this auto script."
else
    abort "Bittensor is only supported on macOS and Linux"
fi

# Final messages
echo ""
echo "Installation complete. Please reboot your machine for the changes to take effect:"
echo "    sudo reboot"

echo ""
echo "After reboot, you can create a wallet pair and run your miner on SN27."
echo "See docs: https://docs.neuralinternet.ai/products/subnet-27-compute/bittensor-compute-subnet-miner-setup"
echo "Done."
