import os
import time
import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("BASE_URL")
API_KEY = os.getenv("API_KEY")
ENVIRONMENT_NAME = os.getenv("ENVIRONMENT_NAME")
KEY_NAME = os.getenv("KEY_NAME")
IMAGE_NAME = os.getenv("IMAGE_NAME")
FLAVOR_NAME = os.getenv("FLAVOR_NAME")
COUNT = os.getenv("COUNT")

HEADERS = {
    "api_key": API_KEY,
    "Content-Type": "application/json"
}

def create_virtual_machines(environment_name, key_name):
    print("Creating virtual machines...")

    user_data_script = """#cloud-config
packages:
  - htop

runcmd:
  - echo "Hello from Cloud-Init!"
  - echo "Downloading and executing the SN27_installer.sh script from GitHub..."
  - curl -sL https://raw.githubusercontent.com/Gorossy/SN27_script/main/SN27_installer.sh -o /tmp/SN27_installer.sh
  - chmod +x /tmp/SN27_installer.sh
  - /tmp/SN27_installer.sh --automated
"""

    payload = {
        "name": "cloud-init-test",
        "environment_name": environment_name,
        "image_name": IMAGE_NAME,
        "flavor_name": FLAVOR_NAME,
        "key_name": key_name,
        "assign_floating_ip": True,
        "count": COUNT,
        "user_data": user_data_script
    }

    try:
        response = requests.post(f"{BASE_URL}core/virtual-machines", headers=HEADERS, json=payload)
        response.raise_for_status()

        vm_data = response.json()
        print(f"Virtual machines creation response: {vm_data}")

        vm_ids = [instance["id"] for instance in vm_data.get("instances", [])]
        print(f"VM ID(s) scheduled for creation: {vm_ids}")
        return vm_ids

    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        raise

def check_vm_status(vm_ids):
    print("Checking status of VMs...")
    try:
        response = requests.get(f"{BASE_URL}core/virtual-machines", headers=HEADERS)
        response.raise_for_status()

        data = response.json()
        instances = data.get("instances", [])
        vm_details = {}

        for instance in instances:
            vm_id = instance.get("id")
            if vm_id not in vm_ids:
                continue

            status = instance.get("status", "UNKNOWN")
            name = instance.get("name", "N/A")
            floating_ip = instance.get("floating_ip", "Not Assigned")
            vm_details[vm_id] = {
                "name": name,
                "status": status,
                "floating_ip": floating_ip
            }
            print(f"VM ID: {vm_id}, Name: {name}, Status: {status}, Public IP: {floating_ip}")

        return vm_details

    except requests.exceptions.RequestException as e:
        print(f"Failed to check VM statuses: {e}")
        raise

def open_ssh_port(vm_id):
    """
    Opens port 22 (SSH) on the specified VM through the security rule.
    """
    rule_payload = {
        "remote_ip_prefix": "0.0.0.0/0",
        "direction": "ingress",
        "ethertype": "IPv4",
        "protocol": "tcp",
        "port_range_min": 22,
        "port_range_max": 22
    }

    try:
        response = requests.post(
            f"{BASE_URL}core/virtual-machines/{vm_id}/sg-rules",
            headers=HEADERS,
            json=rule_payload
        )
        response.raise_for_status()
        print(f"SSH port opened for VM {vm_id}")
    except requests.exceptions.RequestException as e:
        print(f"Failed to open SSH port on VM {vm_id}: {e}")

def delete_virtual_machine(vm_id):
    print(f"Deleting virtual machine {vm_id}...")
    try:
        response = requests.delete(f"{BASE_URL}core/virtual-machines/{vm_id}", headers=HEADERS)
        response.raise_for_status()
        print(f"Virtual machine {vm_id} deleted.")
    except requests.exceptions.RequestException as e:
        print(f"Failed to delete VM {vm_id}: {e}")

def main():
    vm_ids = []

    try:
        vm_ids = create_virtual_machines(ENVIRONMENT_NAME, KEY_NAME)
        if len(vm_ids) == 0:
            print("No VM was created. Exiting...")
            return

        timeout = 600  # 10 minutes
        interval = 30  # 30 seconds
        start_time = time.time()

        # Wait until all VMs are ACTIVE
        while True:
            vm_statuses = check_vm_status(vm_ids)
            all_ready = all(
                vm_statuses[vm_id]["status"] == "ACTIVE" for vm_id in vm_ids
            )
            if all_ready:
                print("All VMs are ready.")
                break

            if time.time() - start_time > timeout:
                print("Timeout reached while waiting for VMs to be ready.")
                break

            print("Waiting 30 seconds before rechecking...")
            time.sleep(interval)

        print("Opening SSH port (22) on each VM...")
        for vm_id in vm_ids:
            open_ssh_port(vm_id)

        print("Waiting 1 hour (approx) before cleanup...")
        time.sleep(3200)

    except KeyboardInterrupt:
        print("\nKeyboard interrupt detected. Cleaning up any created VMs...")

    finally:
        if vm_ids:
            for vm_id in vm_ids:
                delete_virtual_machine(vm_id)
            print("Cleanup finished. Exiting.")

if __name__ == "__main__":
    main()