# Manual Installation of Compute-Subnet

## Description
This project contains an **installation script** that, when executed, takes care of:
* **Cloning** the Compute-Subnet repository automatically.
* **Installing** Docker, NVIDIA drivers if not detected, PM2, Bittensor, and other necessary dependencies.
* **Configuring** Python, virtual environments, and OpenCL libraries.

## Installation Steps

1. **Run the installation script**
   * The script will display the components to install
   * It will request confirmation for:
     - UFW configuration (ports)
     - Increase of `ulimit`
   * The following will be installed automatically:
     - Docker
     - NVIDIA drivers
     - Other necessary tools

2. **WANDB Configuration**
   ```bash
   cd Compute-Subnet
   cp .env.example .env
   ```
   * Edit the `.env` file to configure:
     - WANDB_KEY (required for operation)

3. **Create Bittensor Wallet**
   ```bash
   btcli new_coldkey
   btcli new_hotkey
   ```
   This step is necessary for interaction with the Bittensor network.

## Installation Details
* The script automatically clones `Compute-Subnet`
* UFW will configure the specified port ranges
* All necessary Python dependencies will be installed

## Post-Installation Verification

1. **Verify Docker and CUDA:**
   ```bash
   docker --version
   nvidia-smi
   ```

2. **Confirm Python dependencies:**
   ```bash
   cd Compute-Subnet
   pip list
   ```

3. **Check the configuration:**
   * Complete `.env` file with WANDB_KEY
   * Bittensor wallet created and configured
   * UFW ports open according to specifications

## Troubleshooting

### Docker
* Verify that the repositories were added correctly
* Confirm that the service is active: `systemctl status docker`

### NVIDIA Drivers
* Ensure compatibility with your distribution
* Check logs in `/var/log/nvidia-installer.log`

### Bittensor
* Confirm the existence of the keys in `~/.bittensor/wallets/`
* Verify the connection to the network: `btcli status`

## Additional Documentation
* Bittensor: [bittensor.com/documentation](https://bittensor.com/documentation)
* Compute-Subnet: [GitHub Repository](https://github.com/opentensor/compute-subnet)
* WANDB: [wandb.ai/guides](https://wandb.ai/guides)