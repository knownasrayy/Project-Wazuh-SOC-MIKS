<#
.SYNOPSIS
Script Otomatisasi Azure VM untuk Proyek Wazuh

.DESCRIPTION
Script ini akan membuat Resource Group, Network Security Group (NSG), 
serta 3 buah Virtual Machine (Manager, Agent Target, dan Agent Attacker)
di Azure menggunakan akun Azure for Students (Free Tier).
Public Key (id_rsa.pub) lokal Anda akan otomatis disuntikkan ke dalam VM.
#>

$ResourceGroup = "miks-wazuh-rg"
$Location = "southeastasia" # Anda bisa ganti ke "eastus" jika kuota habis
$AdminUser = "azureuser"
$SshKeyPath = "$HOME\.ssh\id_rsa.pub"

# Memastikan file public key ada
if (-Not (Test-Path $SshKeyPath)) {
    Write-Error "Public key tidak ditemukan di $SshKeyPath! Harap generate SSH key terlebih dahulu."
    Exit
}

Write-Host "🚀 Memulai Provisioning Infrastruktur Wazuh di Azure..." -ForegroundColor Cyan

# 1. Create Resource Group
Write-Host "[1/5] Membuat Resource Group: $ResourceGroup..."
az group create --name $ResourceGroup --location $Location | Out-Null

# 2. Create Network Security Group (NSG) and Rules
Write-Host "[2/5] Mengatur Firewall (Network Security Group)..."
$NSG = "wazuh-nsg"
az network nsg create --resource-group $ResourceGroup --name $NSG | Out-Null

# Buka Port SSH (22)
az network nsg rule create --resource-group $ResourceGroup --nsg-name $NSG --name Allow-SSH --priority 1000 --destination-port-ranges 22 --access Allow --protocol Tcp | Out-Null
# Buka Port Wazuh Dashboard (443)
az network nsg rule create --resource-group $ResourceGroup --nsg-name $NSG --name Allow-Dashboard --priority 1010 --destination-port-ranges 443 --access Allow --protocol Tcp | Out-Null
# Buka Port Wazuh Agent Connection (1514, 1515)
az network nsg rule create --resource-group $ResourceGroup --nsg-name $NSG --name Allow-Wazuh-Agent --priority 1020 --destination-port-ranges 1514 1515 --access Allow --protocol Tcp | Out-Null
# Buka Port HTTP untuk simulasi DDoS (80)
az network nsg rule create --resource-group $ResourceGroup --nsg-name $NSG --name Allow-HTTP --priority 1030 --destination-port-ranges 80 --access Allow --protocol Tcp | Out-Null

# 3. Create VM1 (Wazuh Manager)
Write-Host "[3/5] Membuat VM1 (Manager) - Standard_B2s..." -ForegroundColor Yellow
az vm create `
    --resource-group $ResourceGroup `
    --name vm1-manager `
    --image Ubuntu2204 `
    --size Standard_B2s `
    --admin-username $AdminUser `
    --ssh-key-values $SshKeyPath `
    --nsg $NSG `
    --public-ip-sku Standard | Out-Null

# 4. Create VM2 (Agent Target)
Write-Host "[4/5] Membuat VM2 (Agent Target) - Standard_B1s..." -ForegroundColor Yellow
az vm create `
    --resource-group $ResourceGroup `
    --name agent-vm2 `
    --image Ubuntu2204 `
    --size Standard_B1s `
    --admin-username $AdminUser `
    --ssh-key-values $SshKeyPath `
    --nsg $NSG `
    --public-ip-sku Standard | Out-Null

# 5. Create VM3 (Agent Attacker)
Write-Host "[5/5] Membuat VM3 (Agent Attacker) - Standard_B1s..." -ForegroundColor Yellow
az vm create `
    --resource-group $ResourceGroup `
    --name agent-vm3 `
    --image Ubuntu2204 `
    --size Standard_B1s `
    --admin-username $AdminUser `
    --ssh-key-values $SshKeyPath `
    --nsg $NSG `
    --public-ip-sku Standard | Out-Null

Write-Host "✅ Selesai! Mengambil daftar IP Address..." -ForegroundColor Green

# Menampilkan hasil IP Address
az vm list-ip-addresses --resource-group $ResourceGroup --output table

Write-Host "`nSekarang Anda dapat masuk ke VM dengan perintah: ssh azureuser@<IP_ADDRESS>" -ForegroundColor Cyan
