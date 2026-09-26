# Prepares the Windows PC as the SFTP target of the Backrest (restic) repository.
# Run it ONCE, in an ELEVATED PowerShell (Run as administrator), with the public key generated on the N100 :
#
#   .\setup-sftp-target.ps1 -PublicKey "ssh-ed25519 AAAA... backrest@n100"
#
# What it does :
#   1. installs and starts the OpenSSH server
#   2. creates a local "backup" user, NOT administrator, whose password is never used (key authentication only)
#   3. creates the repository folder, readable and writable by "backup" only (plus read access for you, so that
#      your cloud sync can read it)
#   4. restricts "backup" to SFTP, with its authorized key in ProgramData (see the note below)
#   5. only allows the N100 through the firewall

param(
    [Parameter(Mandatory = $true)][string]$PublicKey,
    [string]$RepoPath = "D:\Backups\N100",
    [string]$N100Ip = "192.168.0.16",
    [string]$UserName = "backup"
)

$ErrorActionPreference = "Stop"

# 1. OpenSSH server. The first start generates the host keys and the default sshd_config
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# 2. Dedicated local user, with a random password nobody needs to know
if (-not (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $password = ConvertTo-SecureString ([Convert]::ToBase64String($bytes) + "aA1!") -AsPlainText -Force
    New-LocalUser -Name $UserName -Password $password -PasswordNeverExpires -UserMayNotChangePassword `
        -Description "SFTP target of the N100 backups (restic)" | Out-Null
    # Hidden from the Windows logon screen
    $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name $UserName -Value 0 -PropertyType DWord -Force | Out-Null
}

# 3. Repository folder : full control for the backup user, read-only for you, no inherited permissions
New-Item -ItemType Directory -Force -Path $RepoPath | Out-Null
icacls $RepoPath /inheritance:r /grant:r `
    "${UserName}:(OI)(CI)F" `
    "$($env:USERNAME):(OI)(CI)RX" `
    "Administrators:(OI)(CI)F" `
    "SYSTEM:(OI)(CI)F" | Out-Null

# 4. Authorized key in ProgramData rather than in the user profile : the profile folder (C:\Users\backup) only exists
#    after the first logon, and a folder created by hand beforehand is not used by Windows. Same ACL as the
#    administrators_authorized_keys file, otherwise sshd ignores it
$keyFile = "$env:ProgramData\ssh\${UserName}_authorized_keys"
Set-Content -Path $keyFile -Value $PublicKey -Encoding ascii
icacls $keyFile /inheritance:r /grant:r "Administrators:F" "SYSTEM:F" | Out-Null

$sshdConfig = "$env:ProgramData\ssh\sshd_config"
if (-not (Select-String -Path $sshdConfig -Pattern "^Match User $UserName$" -Quiet)) {
    # Match blocks must stay at the end of the file
    Add-Content -Path $sshdConfig -Encoding ascii -Value @"

# N100 backups (restic over SFTP) : key authentication, SFTP only, nothing else
Match User $UserName
    AuthorizedKeysFile __PROGRAMDATA__/ssh/${UserName}_authorized_keys
    PasswordAuthentication no
    ForceCommand internal-sftp
    AllowTcpForwarding no
    AllowAgentForwarding no
    PermitTTY no
"@
}
Restart-Service sshd

# 5. Firewall : the rule created by the OpenSSH installation accepts everybody, only the N100 from now on
Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -RemoteAddress $N100Ip

Write-Host "Done. SFTP target ready : ${UserName}@$(hostname) -> $RepoPath (restic path : /$($RepoPath -replace '\\', '/'))"
