#!/bin/bash

clear
DESTINATION_DIR="/usr/local/bin"
BINARY_NAME="fizz"
VERSION="latest"

# Fizz variables
GATEWAY_ADDRESS="provider.testnetbsphn.xyz" # Provider domain: example = provider.devnetcsphn.com
GATEWAY_PROXY_PORT="8553" # Proxyport = 8553
GATEWAY_WEBSOCKET_PORT="8544" # ws url of the gateway example= ws://provider.devnetcsphn.com:8544
CPU_PRICE="3"
CPU_UNITS="4"
MEMORY_PRICE="0.8"
MEMORY_UNITS="8"
STORAGE_PRICE="1.2"
WALLET_ADDRESS="0xD26391EDa2500DC5c958A92a73DFA39430B1C310" 
USER_TOKEN="0xed11cad3130968a8bc4938ff82f99dfbabe08c507ba8db8c0cc316f416c652331daa899a70c706943478213dc75b0ff2113a7928c98994d290a0ee793ce75d9100"
STORAGE_UNITS="120"
GPU_MODEL="rtx3080"
GPU_UNITS="1"
GPU_PRICE="144"
GPU_MEMORY="<gpu-memory>"

# Function to display system information
display_system_info() {
    echo "System Information:"
    echo "==================="
    
    # CPU information
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc)
    echo "Available CPU cores: $cpu_cores"
    
    # Memory information
    if [[ "$OSTYPE" == "darwin"* ]]; then
        total_memory=$(sysctl -n hw.memsize | awk '{printf "%.2f GB", $1 / 1024 / 1024 / 1024}')
        available_memory=$(vm_stat | awk '/Pages free/ {free=$3} /Pages inactive/ {inactive=$3} END {printf "%.2f GB", (free+inactive)*4096/1024/1024/1024}')
    else
        total_memory=$(free -h | awk '/^Mem:/ {print $2}')
        available_memory=$(free -h | awk '/^Mem:/ {print $7}')
    fi
    echo "Total memory: $total_memory"
    echo "Available memory: $available_memory"
    
     if command -v nvidia-smi &> /dev/null; then
        echo -e "\nNVIDIA GPU Information:"
        echo "========================"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    fi
    
}

# Check for 'info' flag
if [ "$1" == "info" ]; then
    display_system_info
    exit 0
fi

echo "===================================="
echo "      SPHERON FIZZ INSTALLER        "
echo "===================================="
echo ""
echo "$BINARY_NAME $VERSION"
echo ""

# Detect the operating system and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Detecting system configuration..."
echo "Operating System: $OS"
echo "Architecture: $ARCH"
echo ""
echo ""
display_system_info 
# Function to install Docker and Docker Compose on macOS
install_docker_mac() {
    echo "Installing Docker for macOS..."
    if command -v brew &>/dev/null; then
        brew install --cask docker
    else
        echo "Homebrew is not installed. Please install Homebrew first:"
        echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    echo "Docker for macOS has been installed. Please start Docker from your Applications folder."
    echo "Docker Compose is included with Docker for Mac."
}

# Function to install Docker and Docker Compose on Ubuntu/Debian
install_docker_ubuntu() {
    if lspci | grep -q NVIDIA; then
        if ! nvidia-smi &>/dev/null; then
            echo "NVIDIA GPU detected, but drivers are not installed. Installing drivers !!!"
            sudo apt update
            sudo apt install -y alsa-utils
            sudo ubuntu-drivers autoinstall
            echo "NVIDIA Driver Installed, rebooting the system"
            echo "Please rerun the script after reboot"
            reboot now
        fi
        echo "NVIDIA GPU detected. Installing NVIDIA Docker"
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

        sudo apt-get update
        sudo apt-get install -y nvidia-docker2
        sudo systemctl restart docker
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo "Nvidia Docker and Docker Compose for Ubuntu/Debian have been installed. You may need to log out and back in for group changes to take effect."
    else 
        echo "Installing Docker for Ubuntu/Debian..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo apt-get install -y docker-compose
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo "Docker and Docker Compose for Ubuntu/Debian have been installed. You may need to log out and back in for group changes to take effect."
    fi
}

# Function to install Docker and Docker Compose on Fedora
install_docker_fedora() {
    echo "Installing Docker for Fedora..."
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker and Docker Compose for Fedora have been installed. You may need to log out and back in for group changes to take effect."
}

# Function to query nvidia-smi and verify GPU information
verify_gpu_info() {
    if command -v nvidia-smi &>/dev/null; then
        echo "Querying NVIDIA GPU information..."
        gpu_count=$(nvidia-smi --list-gpus | wc -l)
        gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits | head -n1)
        gpu_memory_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
        
        # Convert MiB to GiB
        gpu_memory_gib=$(awk "BEGIN {printf \"%.2f\", $gpu_memory_mib / 1024}")
        
        if [ $gpu_count -gt 0 ]; then
            echo "Detected $gpu_count GPU(s)"
            echo "GPU Model: $gpu_model"
            echo "GPU Memory: $gpu_memory_gib Gi"
            
            # Convert GPU_MODEL to lowercase and check if it contains "gpu"
            gpu_model_lower=$(echo "$gpu_model" | tr '[:upper:]' '[:lower:]')
            if [[ $gpu_model_lower == *"$GPU_MODEL"* ]]; then
                GPU_UNITS="$gpu_count"
                GPU_MEMORY="${gpu_memory_gib}Gi"
                
                echo "Updated GPU_MODEL: $GPU_MODEL"
                echo "Updated GPU_UNITS: $GPU_UNITS"
                echo "Updated GPU_MEMORY: $GPU_MEMORY GiB"
            else
                echo "GPU model does not contain 'gpu'. Skipping GPU_MODEL, GPU_UNITS, and GPU_MEMORY update."
            fi
        else
            echo "No NVIDIA GPU detected."
        fi
    else
        echo "nvidia-smi command not found. Unable to verify GPU information."
    fi
}

# Check if docker is installed
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Please install Docker to continue."
    echo "For more information, please refer to https://docs.docker.com/get-docker/"
    # Detect OS and install Docker and Docker Compose accordingly
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install_docker_mac
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
                install_docker_ubuntu
            elif [[ "$ID" == "fedora" ]]; then
                install_docker_fedora
            else
                echo "Unsupported Linux distribution. Please install Docker and Docker Compose manually."
                exit 1
            fi
        else
            echo "Unable to determine Linux distribution. Please install Docker and Docker Compose manually."
            exit 1
        fi
    else
        echo "Unsupported operating system. Please install Docker and Docker Compose manually."
        exit 1
    fi

    # Verify Docker and Docker Compose installation
    if command -v docker &>/dev/null && command -v docker compose &>/dev/null; then
        echo "Docker and Docker Compose have been successfully installed."
        docker --version
        docker compose version
    else
        echo "Docker and/or Docker Compose installation failed. Please try installing manually."
        exit 1
    fi
fi

# Verify GPU information
verify_gpu_info

# Create config file
mkdir -p ~/.spheron/fizz
mkdir -p ~/.spheron/fizz-manifests
echo "Creating yml file..."
cat << EOF > ~/.spheron/fizz/docker-compose.yml
version: '2.2'

services:
  fizz:
    image: spheronnetwork/fizz:latest
    network_mode: "host"
    pull_policy: always
    privileged: true
    cpus: 1
    mem_limit: 512M
    restart: always
    environment:
      - GATEWAY_ADDRESS=$GATEWAY_ADDRESS
      - GATEWAY_PROXY_PORT=$GATEWAY_PROXY_PORT
      - GATEWAY_WEBSOCKET_PORT=$GATEWAY_WEBSOCKET_PORT
      - CPU_PRICE=$CPU_PRICE
      - MEMORY_PRICE=$MEMORY_PRICE
      - STORAGE_PRICE=$STORAGE_PRICE
      - WALLET_ADDRESS=$WALLET_ADDRESS
      - USER_TOKEN=$USER_TOKEN
      - CPU_UNITS=$CPU_UNITS
      - MEMORY_UNITS=$MEMORY_UNITS
      - STORAGE_UNITS=$STORAGE_UNITS
      - GPU_MODEL=$GPU_MODEL
      - GPU_UNITS=$GPU_UNITS
      - GPU_PRICE=$GPU_PRICE
      - GPU_MEMORY=$GPU_MEMORY 
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.spheron/fizz-manifests:/.spheron/fizz-manifests

EOF

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Attempting to start Docker..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo systemctl start docker
    else
        echo "Unsupported operating system. Please start Docker manually."
        exit 1
    fi

    # Wait for Docker to start
    echo "Waiting for Docker to start..."
    until docker info >/dev/null 2>&1; do
        sleep 1
    done
    echo "Docker has been started successfully."
fi


# Function to determine which Docker Compose command works
get_docker_compose_command() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        echo ""
    fi
}

# Get the working Docker Compose command
DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo "Error: Neither 'docker-compose' nor 'docker compose' is available."
    exit 1
fi

echo "Starting Fizz..."
$DOCKER_COMPOSE_CMD  -f ~/.spheron/fizz/docker-compose.yml up -d --force-recreate

echo ""
echo "============================================"
echo "Fizz Is Installed and Running successfully"
echo "============================================"
echo ""
echo "To fetch the logs, run:"
echo "$DOCKER_COMPOSE_CMD -f ~/.spheron/fizz/docker-compose.yml logs -f"
echo ""
echo "To stop the service, run:"
echo "$DOCKER_COMPOSE_CMD -f ~/.spheron/fizz/docker-compose.yml down"
echo ""
echo "============================================"
echo "Thank you for installing Fizz! 🎉"
echo "============================================"
echo ""