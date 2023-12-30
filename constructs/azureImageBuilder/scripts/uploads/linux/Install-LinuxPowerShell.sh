# Source: https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.4

echo '##########################################'
echo '#   Entering Install-LinuxPowerShell.sh   #'
echo '##########################################'

# Update the list of packages
sudo apt-get update

# Install pre-requisite packages.
sudo apt-get install -y wget apt-transport-https software-properties-common

# Get the version of Ubuntu
source /etc/os-release

# Download the Microsoft repository GPG keys
wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb

# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb

# Delete the Microsoft repository keys file
rm packages-microsoft-prod.deb

# Update the list of products
sudo apt-get update

# Enable the "universe" repositories
sudo add-apt-repository universe

# Install PowerShell
sudo apt-get install -y powershell

echo '#########################################'
echo '#   Exiting Install-LinuxPowerShell.sh   #'
echo '#########################################'

exit 0
