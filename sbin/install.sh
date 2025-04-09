#!/bin/bash
#

# get the tmp path
if [[ $1 == */ ]]; then
  TMP_PATH=${1%?}
else
  TMP_PATH=$1
fi

VERSION=$2

# create tmp dir
mkdir -p $TMP_PATH

cd $TMP_PATH

# 设置 debconf 前端为 Noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

curl -o NVIDIA-Linux-x86_64-$VERSION.run --request GET --url https://cn.download.nvidia.cn/XFree86/Linux-x86_64/$VERSION/NVIDIA-Linux-x86_64-$VERSION.run --header 'Accept: */*' --header 'Accept-Encoding: gzip, deflate, br' --header 'Connection: keep-alive' --header 'Referer: https://www.nvidia.cn/' --header 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0'
if [ $? -ne 0 ]; then
    echo "Driver file download failed"
    echo "{\"installVersion\":\"$VERSION\",\"error\":\"Driver file download failed\"}" > "./info.json"
    exit 1
fi

# set ustc sources
cat > /etc/apt/sources.list.d/nvidia-driver-installer-ext.list << EOF
deb https://mirrors.ustc.edu.cn/debian/ bullseye main contrib non-free
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye main contrib non-free
 
deb https://mirrors.ustc.edu.cn/debian/ bullseye-updates main contrib non-free
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye-updates main contrib non-free
 
deb https://mirrors.ustc.edu.cn/debian/ bullseye-backports main contrib non-free
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye-backports main contrib non-free
 
deb https://mirrors.ustc.edu.cn/debian-security/ bullseye-security main contrib non-free
deb-src https://mirrors.ustc.edu.cn/debian-security/ bullseye-security main contrib non-free
EOF


# Ensure no pending updates:
sudo apt-get update -o Dir::Etc::SourceList=/etc/apt/sources.list.d/nvidia-driver-installer-ext.list
# sudo apt-get upgrade -y
sleep 1
# clear

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"5%\"}" > "./info.json"

# blacklist the Nouveau driver so it doesn't initialize:
sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sleep 1
# clear

# apt-get install -y gcc g++ cmake pkg-config libglvnd-dev 
# apt-get install -y linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')
# service gdm3 stop

# Check if gcc installed
gccInstalled="false"
if which gcc > /dev/null 2>&1; then
  gccInstalled="true"
else
  sudo apt-get install -y gcc
fi

# Check if make installed
makeInstalled="make"
if which make > /dev/null 2>&1; then
   makeInstalled="true" 
else
  sudo apt-get install -y make
fi

# Check if gcc installed
pkgConfigInstalled="false"
if which pkg-config > /dev/null 2>&1; then
   pkgConfigInstalled="true"
else
  sudo apt-get install -y pkg-config 
fi

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"10%\"}" > "./info.json"

# apt-get install -y gcc make pkg-config libglvnd-dev
sudo apt-get install -y libglvnd-dev
sudo apt-get install -y linux-headers-$(uname -r)

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"20%\"}" > "./info.json"

chmod +x ./NVIDIA-Linux-x86_64-$VERSION.run
# Silent installation of nvidia driver
./NVIDIA-Linux-x86_64-$VERSION.run --accept-license --no-x-check --no-nouveau-check --silent --ui=none --no-questions

# Check if the current driver version is the version you want to install
currentVersion=$(modinfo nvidia | grep ^version: | sed 's/^version:\s*//')

if [ "$currentVersion" != "$VERSION" ];then
  rm -f NVIDIA-Linux-x86_64-$VERSION.run
  # restore sources
  rm -f /etc/apt/sources.list.d/nvidia-driver-installer-ext.list
  sudo apt-get update
  echo "{\"installVersion\":\"$VERSION\",\"error\":\"Driver installation failed\"}" > "./info.json"
  echo "Driver installation failed"
  exit 1
fi

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"80%\"}" > "./info.json"

# Uninstall programs installed for compiling drivers
if [ "$gccInstalled" == "false" ];then
  echo "Uninstall gcc" 
  sudo apt-get purge -y --auto-remove gcc
fi

if [ "$makeInstalled" == "false" ];then
  echo "Uninstall make" 
  sudo apt-get purge -y --auto-remove make
fi

if [ "$pkgConfigInstalled" == "false" ];then
  echo "Uninstall pkg-config" 
  sudo apt-get purge -y --auto-remove pkg-config
fi

# clear

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"85%\"}" > "./info.json"
echo "Start install nvidia-container-toolkit" 

if [ ! -f "/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg" ]; then
  # if GPG key not exist, pulls GPG key, adds it to your key files
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
fi

#sets variable for your local distribution:
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

# pulls the latest libnvidia-container from nvidia for your build, and pipes it to a sources file for installation:
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit-ext.list

# updates with latest sources:
sudo apt-get update -o Dir::Etc::SourceList=/etc/apt/sources.list.d/nvidia-driver-installer-ext.list \
  -o Dir::Etc::SourceList=/etc/apt/sources.list.d/nvidia-container-toolkit-ext.list

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"90%\"}" > "./info.json"

# install the toolkit
sudo apt-get install -y nvidia-container-toolkit

# Check if Docker service exists
if ! which docker > /dev/null 2>&1; then
    echo "Docker command not found, the system may not have Docker installed."
    rm -f NVIDIA-Linux-x86_64-$VERSION.run
    # restore sources
    rm -f /etc/apt/sources.list.d/nvidia-driver-installer-ext.list
    rm -f tee /etc/apt/sources.list.d/nvidia-container-toolkit-ext.list
    sudo apt-get update
    echo "{\"installVersion\":\"$VERSION\",\"progress\":\"100%\"}" > "./info.json"
    # installation is complete
    echo "Installation completed, as Docker is not installed in the system, Docker runtime will not be configured"
    exit 0
fi

if cat /etc/docker/daemon.json | test -z "$(cat /etc/docker/daemon.json)"; then
    # if daemon.json is empty, write an empty json
  echo "{}" > "/etc/docker/daemon.json"
fi

# Configure Docker to use NVIDIA Container Runtime
sudo nvidia-ctk runtime configure --runtime=docker

#check that the runtime is installed, otherwise fail with error:
if which nvidia-container-runtime-hook >/dev/null; then
  echo "container-runtime found, continuing"
else
  echo "Runtime failed, did you run this script with sudo?"
  rm -f NVIDIA-Linux-x86_64-$VERSION.run
  # restore sources
  rm -f /etc/apt/sources.list.d/nvidia-driver-installer-ext.list
  rm -f tee /etc/apt/sources.list.d/nvidia-container-toolkit-ext.list
  sudo apt-get update
  echo "{\"installVersion\":\"$VERSION\",\"error\":\"Runtime failed\"}" > "./info.json"
  exit 1
fi

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"95%\"}" > "./info.json"

# restart docker service
sudo systemctl restart docker
# clear

# installation is complete
echo "Installation is complete"

rm -f NVIDIA-Linux-x86_64-$VERSION.run
# restore sources
rm -f /etc/apt/sources.list.d/nvidia-driver-installer-ext.list
rm -f tee /etc/apt/sources.list.d/nvidia-container-toolkit-ext.list
sudo apt-get update

echo "{\"installVersion\":\"$VERSION\",\"progress\":\"100%\"}" > "./info.json"
