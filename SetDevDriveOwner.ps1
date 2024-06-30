function Get-DevDrive {
    $devDrives = Get-Volume | Where-Object { $_.FileSystemType -eq 'ReFS' -and $_.DriveType -eq 'Fixed' }
    $devDriveLetters = @()
    
    foreach ($drive in $devDrives) {
        $driveLetter = "$($drive.DriveLetter):"
        Write-Host "`nDev Drive found: $driveLetter"
        $devDriveLetters += $driveLetter
    }
    
    if ($devDriveLetters.Count -eq 0) {
        Write-Output "No Dev Drive found on the system."
        return $null
    } elseif ($devDriveLetters.Count -eq 1) {
        return $devDriveLetters[0]
    } else {
        Write-Host "Multiple Dev Drives found:"
        for ($i = 0; $i -lt $devDriveLetters.Count; $i++) {
            Write-Host "[$i] $($devDriveLetters[$i])"
        }
        $selection = Read-Host "Please select the drive you want to configure by entering the corresponding number"
        if ($selection -match '^\d+$' -and [int]$selection -lt $devDriveLetters.Count) {
            return $devDriveLetters[$selection]
        } else {
            Write-Output "Invalid selection. Exiting script."
            return $null
        }
    }
}

function Set-DevDrivePermissions {
    param (
        [string]$driveLetter
    )

    # Ensure the drive letter is correctly formatted
    if (-not $driveLetter.EndsWith(':')) {
        $driveLetter += ':'
    }

    # Define the user
    $userName = "$env:USERDOMAIN\$env:USERNAME"

    # Get the current ACL (Access Control List) for the drive
    $acl = Get-Acl $driveLetter

    # Create a new access rule for the user with full control
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($userName, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

    # Add the new access rule to the ACL
    $acl.SetAccessRule($accessRule)

    # Apply the new ACL to the drive
    Set-Acl $driveLetter $acl

    # Hide the drive from other users
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    $regName = "NoDrives"
    $driveLetterOnly = $driveLetter.TrimEnd(':')  # Get just the letter part
    $driveNumber = [math]::Pow(2, ([byte][char]$driveLetterOnly) - 65)

    # Set the registry key to hide the drive
    If (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    Set-ItemProperty -Path $regPath -Name $regName -Value $driveNumber

    Write-Output "`nDev Drive ($driveLetter) is now only accessible and visible to the user $userName."
}

function Test-DevDrivePermissions {
    param (
        [string]$driveLetter
    )

    Write-Output "`nReviewing permissions for Dev Drive ($driveLetter)..."

    # Get the current ACL for the drive
    $acl = Get-Acl $driveLetter

    # Output the permissions
    $acl.Access | Format-List | Out-Host

    Write-Output "Permissions review completed."
}

# Main script execution
$devDrive = Get-DevDrive

if ($null -ne $devDrive) {
    Set-DevDrivePermissions -driveLetter $devDrive

    # Periodically review permissions (this could be scheduled as a task or run manually)
    Test-DevDrivePermissions -driveLetter $devDrive
} else {
    Write-Output "No Dev Drive was configured."
}
