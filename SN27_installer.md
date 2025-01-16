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
# SUBTENSOR
################################################################################
linux_install_subtensor() {
    ohai "Cloning subtensor into ~/subtensor"
    mkdir -p ~/subtensor
    sudo apt install -y git
    git clone https://github.com/opentensor/subtensor.git
    cd subtensor
}

################################################################################
# PYTHON
################################################################################
linux_install_python() {
    if ! which "$python" >/dev/null 2>&1; then
        ohai "Installing python"
        sudo apt-get install --no-install-recommends --no-install-suggests -y "$python"
    else
        ohai "Upgrading python"
        sudo apt-get install --only-upgrade "$python"
    fi
    exit_on_error $?

    ohai "Installing python dev tools"
    sudo apt-get install --no-install-recommends --no-install-suggests -y \
      "${python}-pip" "${python}-dev"
    exit_on_error $?
}

linux_update_pip() {
    ohai "Upgrading pip"
    "$python" -m pip install --upgrade pip
}

################################################################################
# BITTENSOR
################################################################################
linux_install_bittensor() {
    ohai "Cloning bittensor@master into ~/.bittensor/bittensor"
    mkdir -p ~/.bittensor/bittensor
    git clone https://github.com/opentensor/bittensor.git \
      ~/.bittensor/bittensor/ 2>/dev/null || \
      ( cd ~/.bittensor/bittensor/ && git fetch origin master && git checkout master && git pull --ff-only && git reset --hard && git clean -xdf )
    ohai "Installing bittensor"
    "$python" -m pip install -e ~/.bittensor/bittensor/
    exit_on_error $?
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
# COMPUTE-SUBNET
################################################################################
linux_install_compute_subnet() {
    ohai "Cloning Compute-Subnet into ~/Compute-Subnet"
    mkdir -p ~/Compute-Subnet
    git clone https://github.com/neuralinternet/Compute-Subnet.git ~/Compute-Subnet/ 2>/dev/null || \
      ( cd ~/Compute-Subnet/ && git pull --ff-only && git reset --hard && git clean -xdf )

    ohai "Installing Compute-Subnet dependencies"
    cd ~/Compute-Subnet
    "$python" -m pip install -r requirements.txt
    "$python" -m pip install --no-deps -r requirements-compute.txt
    "$python" -m pip install -e .
    sudo apt -y install ocl-icd-libopencl1 pocl-opencl-icd

    ohai "Starting Docker service, adding user to docker, installing 'at' package"
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    sudo systemctl start docker
    sudo apt install -y at

    cd ~
    exit_on_error $?
}

################################################################################
# HASHCAT
################################################################################
linux_install_hashcat() {
    ohai "Installing Hashcat"
    wget https://hashcat.net/files/hashcat-6.2.6.tar.gz
    tar xzvf hashcat-6.2.6.tar.gz
    cd hashcat-6.2.6/
    sudo make
    sudo make install
    export PATH=$PATH:/usr/local/bin/
    echo "export PATH=$PATH" >>~/.bashrc
    cd ~
}

################################################################################
# NVIDIA CUDA
################################################################################
linux_install_nvidia_cuda() {
    ohai "Removing old NVIDIA drivers (if any)"
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get remove --purge -y '^nvidia.*'
        sudo apt-get autoremove -y
        sudo dpkg --configure -a
        sudo apt-get install -f -y
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf remove -y nvidia* || true
    fi

    ohai "Installing build essentials"
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y build-essential dkms linux-headers-$(uname -r)
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf group install -y "Development Tools"
        sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
    fi

    ohai "Installing CUDA"
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda-repo-ubuntu2204-12-3-local_12.3.1-545.23.08-1_amd64.deb \
          -O /tmp/cuda-repo.deb
        sudo dpkg -i /tmp/cuda-repo.deb
        sudo cp /var/cuda-repo-ubuntu2204-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
        sudo apt-get update
        sudo apt-get -y install cuda-toolkit-12-3
        sudo apt-get -y install cuda-drivers

    elif command -v dnf >/dev/null 2>&1; then
        # RHEL/Rocky
        wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda-repo-rhel9-12-3-local-12.3.1-545.23.08-1.x86_64.rpm \
          -O /tmp/cuda-repo.rpm
        sudo rpm --install /tmp/cuda-repo.rpm
        sudo dnf clean all
        sudo dnf -y update
        sudo dnf -y install cuda
    else
        ohai "Unsupported distribution for NVIDIA CUDA installation."
        exit 1
    fi

    ohai "Configuring environment variables"
    export CUDA_VERSION="cuda-12.3"
    {
      echo ""
      echo "# Added by NVIDIA CUDA install script"
      echo "export CUDA_VERSION=${CUDA_VERSION}"
      echo "export PATH=\$PATH:/usr/local/\$CUDA_VERSION/bin"
      echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/\$CUDA_VERSION/lib64"
    } >>~/.bashrc

    # Load them in the current session
    source ~/.bashrc

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

    # By default, let's just open 2000-5000 (example)
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

    # Check for apt
    which -s apt
    if [[ $? != 0 ]]; then
        abort "This Linux-based install requires apt. For other distros, install requirements manually."
    fi

    # ASCII Banner
    echo "
 ░▒▓███████▓▒░ ░▒▓███████▓▒░        ░▒▓███████▓▒░  ░▒▓████████▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░        ░▒▓█▓▒░ 
 ░▒▓██████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░        ░▒▓██████▓▒░        ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░              ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░             ░▒▓█▓▒░   
░▒▓███████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓████████▓▒░      ░▒▓█▓▒░   

                                                   - Bittensor; Mining a new element.
"

    ohai "Starting auto-install..."
    linux_install_pre
    linux_install_subtensor
    linux_install_python
    linux_update_pip
    linux_install_bittensor
    linux_install_pm2
    linux_install_nvidia_docker
    linux_install_compute_subnet
    linux_install_hashcat
    linux_install_nvidia_cuda
    linux_install_ufw
    linux_increase_ulimit

    echo ""
    echo ""
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##                      BITTENSOR SN27 SETUP                        ##"
    echo "##                                                                  ##"
    echo "######################################################################"
    echo ""

elif [[ "$OS" == "Darwin" ]]; then
    # ... existing Darwin code if needed ...
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
