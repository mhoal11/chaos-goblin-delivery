# Windows setup: the receiving PC

Chaos Goblin delivers files to a **shared folder** on a Windows PC. This is a one-time setup on that PC. It creates:

- a **dedicated local account** that can only drop files into one folder (not your own login),
- a **shared folder** for incoming files,
- **firewall access** for file sharing on your home network only.

Run everything in **PowerShell as Administrator** (Start → type *PowerShell* → right-click → *Run as administrator*). Tested on Windows 10 and 11.

> **Why a separate account?** If you sign in to Windows with a Microsoft account (an email address) or a PIN, sharing logins from Linux often fail with `NT_STATUS_LOGON_FAILURE`. A plain local account with a normal password avoids that, and it limits what the Linux machine can reach to a single folder.

## 1. Create the drop account

```powershell
$pw = Read-Host "Choose a password for scansvc" -AsSecureString
New-LocalUser -Name "scansvc" -Password $pw `
    -FullName "Scanner delivery" `
    -Description "Chaos Goblin Delivery drop account" `
    -PasswordNeverExpires -UserMayNotChangePassword
```

It's a standard user, not an administrator. Use a long password; you'll type it once more into the Linux credentials file.

**Optional:** hide it from the Windows sign-in screen:

```powershell
$k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
New-Item $k -Force | Out-Null
New-ItemProperty $k -Name "scansvc" -Value 0 -PropertyType DWord -Force | Out-Null
```

## 2. Create and share the folder

```powershell
New-Item -ItemType Directory -Path "C:\ScanDrop" -Force | Out-Null

# Folder permission: scansvc can add and change files here
icacls "C:\ScanDrop" /grant "scansvc:(OI)(CI)M"

# Share it: scansvc can write, administrators keep full control
New-SmbShare -Name "ScanDrop" -Path "C:\ScanDrop" `
    -ChangeAccess "scansvc" -FullAccess "Administrators"
```

Windows checks both the **share** permission and the **folder** permission, so both are needed.

## 3. Allow file sharing on your home network

Windows blocks file sharing on networks marked **Public**. Mark your home network **Private**, then enable the sharing rules for Private networks only:

```powershell
Get-NetConnectionProfile                       # note the InterfaceAlias, e.g. "Wi-Fi" or "Ethernet"
Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private

Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" |
    Where-Object { $_.Profile -match 'Private' } |
    Enable-NetFirewallRule
```

*(On a non-English Windows, the rule group name is translated. Use* Control Panel → Network and Sharing Center → Advanced sharing settings → *turn on file and printer sharing for Private networks.)*

## 4. Note the PC's name and address

```powershell
$env:COMPUTERNAME                              # e.g. DESKTOP-AB12CD3
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.PrefixOrigin -eq 'Dhcp' } |
    Select-Object InterfaceAlias, IPAddress
```

So the address doesn't change, give the PC a **DHCP reservation** in your router's settings (look for *DHCP reservation*, *static lease*, or *address reservation*). Or put the computer name in `SMB_HOST` instead of the IP.

## 5. Connect from Linux

Credentials file (`~/.smbcredentials`, then `chmod 600 ~/.smbcredentials`):

```ini
username=scansvc
password=the-password-from-step-1
domain=DESKTOP-AB12CD3
```

`domain` is the **computer name** from step 4: the account belongs to that PC, not to a network domain.

Recipient profile (`~/.config/chaos-goblin/recipients/desktop.conf`):

```bash
DISPLAY_NAME="Desktop PC"
SMB_HOST="192.168.1.50"
SMB_SHARE="ScanDrop"
CREDENTIALS="$HOME/.smbcredentials"
```

Test it:

```bash
smbclient -L //192.168.1.50 -A ~/.smbcredentials          # should list ScanDrop
smbclient //192.168.1.50/ScanDrop -A ~/.smbcredentials -c 'ls'
send-to desktop README.md
```

## Troubleshooting

| Error | Usual cause | Fix |
|---|---|---|
| `NT_STATUS_LOGON_FAILURE` | Wrong password, or the login is being checked against the wrong place | Set `domain=` to the PC's computer name; re-check the password; use the local `scansvc` account, not a Microsoft-account login |
| `NT_STATUS_ACCESS_DENIED` | Share or folder permission missing | Re-run the `icacls` and `New-SmbShare` lines in step 2 |
| `NT_STATUS_BAD_NETWORK_NAME` | Share name typo | `Get-SmbShare` on Windows; match `SMB_SHARE` exactly |
| `NT_STATUS_IO_TIMEOUT` / `Connection refused` | Firewall, or network is set to Public | Step 3; check the PC is awake and on the same network |
| Worked yesterday, not today | PC's IP address changed | DHCP reservation (step 4) |

## Undo everything

```powershell
Remove-SmbShare -Name "ScanDrop" -Force
Remove-LocalUser -Name "scansvc"
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList' -Name "scansvc" -ErrorAction SilentlyContinue
# The C:\ScanDrop folder and its files are left in place; delete it yourself if you want.
```
