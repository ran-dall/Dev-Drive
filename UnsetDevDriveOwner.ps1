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
        $selection = Read-Host "Please select the drive you want to revert by entering the corresponding number"
        if ($selection -match '^\d+$' -and [int]$selection -lt $devDriveLetters.Count) {
            return $devDriveLetters[$selection]
        } else {
            Write-Output "Invalid selection. Exiting script."
            return $null
        }
    }
}

function Remove-DevDrivePermissions {
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

    # Find the access rule for the user
    $accessRule = $acl.Access | Where-Object {
        $_.IdentityReference -eq $userName -and $_.FileSystemRights -eq 'FullControl'
    }

    # Remove the access rule for the user if it exists
    if ($accessRule) {
        $acl.RemoveAccessRule($accessRule) | Out-Null
    }

    # Apply the updated ACL to the drive
    Set-Acl $driveLetter $acl

    # Restore the visibility of the drive for other users
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    $regName = "NoDrives"

    # Check if the registry key exists
    if (Test-Path $regPath) {
        $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

        if ($currentValue) {
            $driveLetterOnly = $driveLetter.TrimEnd(':')
            $driveNumber = [math]::Pow(2, ([byte][char]$driveLetterOnly) - 65)

            # Remove the drive number from the current value
            $newValue = $currentValue.$regName -band (-bnot $driveNumber)

            # Update the registry key with the new value
            Set-ItemProperty -Path $regPath -Name $regName -Value $newValue | Out-Null
        }
    }

    Write-Output "`nDev Drive ($driveLetter) permissions have been reverted for the user $userName."
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
    Remove-DevDrivePermissions -driveLetter $devDrive

    # Review permissions after removal
    Test-DevDrivePermissions -driveLetter $devDrive
} else {
    Write-Output "No Dev Drive was reverted."
}
