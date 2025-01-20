# VM Automation

## Overview
This repository contains a Python script (`main.py`) that automates the creation and management of virtual machines on HyperStack via its API. The script handles VM creation, configuration using Cloud-Init, automatic SSH port opening (port 22), and cleanup operations. VMs are automatically destroyed after a specified waiting period or upon user interruption.

## Environment Variables
All sensitive and environment-specific settings are stored in a `.env` file, which is **not** committed to source control. A reference `.env.example` file is provided as a template.

### Example Configuration (.env.example)
```bash
# Base URL for the NexGenCloud API
BASE_URL="https://infrahub-api.nexgencloud.com/v1/"

# The API key for Infrahub
API_KEY="REPLACE_WITH_YOUR_API_KEY"

# The environment name to use
ENVIRONMENT_NAME="test"

# SSH key name
KEY_NAME="ssh"

# Operating system image name
IMAGE_NAME="Ubuntu Server 22.04 LTS R535 CUDA 12.2"

# Flavor name
FLAVOR_NAME="n3-L40x1"

# Flag to indicate if this script is running in automated mode
# Possible values: "true" or empty
AUTOMATED="true"
```

### Variable Descriptions
- **BASE_URL**: The endpoint for the NexGenCloud API
- **API_KEY**: Your secret API key for authentication (never commit the real key)
- **ENVIRONMENT_NAME**: The environment/project name for VM creation
- **KEY_NAME**: SSH key name configured in the NexGenCloud dashboard
- **IMAGE_NAME**: Operating system image selection (e.g., "Ubuntu Server 22.04 LTS R535 CUDA 12.2")
- **FLAVOR_NAME**: VM specifications/size (e.g., "n3-L40x1")
- **AUTOMATED**: Flag for automatic execution ("true") or interactive mode (empty)

## Setup Instructions

1. Clone the repository and create your environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your actual values:
   ```bash
   BASE_URL="https://infrahub-api.nexgencloud.com/v1/"
   API_KEY="your-real-api-key"
   ENVIRONMENT_NAME="test"
   KEY_NAME="ssh"
   IMAGE_NAME="Ubuntu Server 22.04 LTS R535 CUDA 12.2"
   FLAVOR_NAME="n3-L40x1"
   AUTOMATED="true"
   ```

3. Install required dependencies:
   ```bash
   pip install -r requirements.txt
   ```
   or directly:
   ```bash
   pip install python-dotenv requests
   ```

## Usage

1. Run the script:
   ```bash
   python main.py
   ```

2. The script will automatically:
   - Create VM(s) using your configured settings
   - Monitor VM status until "ACTIVE"
   - Configure SSH access (port 22)
   - Wait approximately 1 hour before cleanup
   - Delete instances automatically

3. Early termination:
   - Press `Ctrl + C` to trigger immediate cleanup
   - The script will safely destroy all created VMs

## Operation Modes

### Automated Mode
Set `AUTOMATED="true"` in `.env` for fully automatic operation. The script will:
- Run without user interaction
- Follow predetermined timing for cleanup
- Handle all operations automatically

### Manual Mode
Remove or leave `AUTOMATED` blank in `.env` for interactive operation. This mode:
- May require user confirmation for certain steps
- Allows for manual timing control
- Provides more detailed operation feedback

## Notes
- Keep your `.env` file secure and never commit it to version control
- Ensure your API key has appropriate permissions
- Monitor VM usage to avoid unexpected costs
