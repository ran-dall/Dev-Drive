# Function to check if a drive is a Dev Drive
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

# Function to test if a Dev Drive is trusted
function Test-DevDriveTrusted {
    param (
        [string]$DriveLetter
    )
    $result = fsutil devdrv query $DriveLetter | Out-String
    return $result -match "This is a trusted developer volume"
}

# Function to get allowed filters on a Dev Drive
function Get-DevDriveAllowedFilters {
    param (
        [string]$DriveLetter
    )
    $result = fsutil devdrv query $DriveLetter | Out-String
    if ($result -match "Filters allowed on this developer volume:\s*(.*)") {
        $allowedFiltersLine = $matches[1]
        $allowedFiltersLine = $allowedFiltersLine.Trim()
        return $allowedFiltersLine -split ",\s*"
    }
    return @()
}

# Function to add filters to a Dev Drive
function Add-DevDriveFilters {
    param (
        [string]$DriveLetter,
        [string[]]$Filters
    )
    $allowedFilters = Get-DevDriveAllowedFilters -DriveLetter $DriveLetter
    $filtersToAdd = $Filters | Where-Object { $allowedFilters -notcontains $_ }
    
    if ($filtersToAdd.Count -gt 0) {
        $filterString = $filtersToAdd -join ","
        try {
            fsutil devdrv setfiltersallowed /f /volume $DriveLetter $filterString > $null
            Write-Output "Filters added to $DriveLetter $filterString"
        } catch {
            Write-Error "Failed to add filters to $DriveLetter $_"
        }
    } else {
        Write-Output "All specified filters are already allowed on $DriveLetter."
    }
}

# Function to prompt the user to add filters
function PromptForFilters {
    param (
        [string]$DriveLetter
    )
    $filters = @()
    
    Write-Host "Default filters: PrjFlt, bindFlt, wcifs, FileInfo, ProcMon24"
    
    $defaultResponse = Read-Host "Would you like to use the default filters? (Y/N)"
    if ($defaultResponse -eq 'Y') {
        $filters += "PrjFlt", "bindFlt", "wcifs", "FileInfo", "ProcMon24"
    } else {
        $filterOptions = @(
            @{ Name = "PrjFlt"; Description = "GVFS: Sparse enlistments of Windows" },
            @{ Name = "MsSecFlt"; Description = "MSSense: Microsoft Defender for Endpoint for EDR Sensor" },
            @{ Name = "WdFilter"; Description = "Defender: Windows Defender Filter" },
            @{ Name = "bindFlt, wcifs"; Description = "Docker: Running containers out of Dev Drive" },
            @{ Name = "FileInfo"; Description = "Windows Performance Recorder: Measure file system operations & Resource Monitor: Shows resource usage. Required to show file names in Disk Activity" },
            @{ Name = "ProcMon24"; Description = "Process Monitor - Sysinternals: Monitor file system activities [EXPERIMENTAL]" },
            @{ Name = "WinSetupMon"; Description = "Windows Upgrade: Used during OS Upgrade. Required if user moves TEMP environment variable to Dev Drive" }
        )

        foreach ($option in $filterOptions) {
            $response = Read-Host "Do you want to add the filter $($option.Name) - $($option.Description)? (Y/N)"
            if ($response -eq 'Y') {
                $filters += $option.Name -split ',\s*'
            }
        }
    }

    Add-DevDriveFilters -DriveLetter $DriveLetter -Filters $filters
}

# Function to check if the Anti-Virus filter is enabled and give the option to change it
function ManageAntiVirusFilter {
    param (
        [string]$DriveLetter
    )
    $result = fsutil devdrv query $DriveLetter | Out-String
    $avEnabled = $result -match "Developer volumes are protected by antivirus filter"

    if ($avEnabled) {
        Write-Host "Developer volumes are currently protected by antivirus filter."
        $response = Read-Host "Do you want to disable the antivirus filter? (Y/N)"
        if ($response -eq 'Y') {
            fsutil devdrv enable /disallowAV > $null
            Write-Output "Antivirus filter has been disabled for Dev Drive $DriveLetter."
        }
    } else {
        Write-Host "Developer volumes are not protected by antivirus filter."
        $response = Read-Host "Do you want to enable the antivirus filter? (Y/N)"
        if ($response -eq 'Y') {
            fsutil devdrv enable /allowAV > $null
            Write-Output "Antivirus filter has been enabled for Dev Drive $DriveLetter."
        }
    }
}

# Main Script
$devDrive = Get-DevDrive

if ($null -ne $devDrive) {
    $isTrusted = Test-DevDriveTrusted -DriveLetter $devDrive
    
    if (-not $isTrusted) {
        $userResponse = Read-Host "`nDev Drive $devDrive is not trusted. Do you want to set it as trusted? (Y/N)"
        if ($userResponse -eq 'Y') {
            fsutil devdrv trust $devDrive > $null
            Write-Output "Dev Drive $devDrive has been set as trusted."
        } else {
            Write-Output "Dev Drive $devDrive remains untrusted."
            exit
        }
    } else {
        Write-Output "`nDev Drive $devDrive is already trusted."
    }

    ManageAntiVirusFilter -DriveLetter $devDrive
    PromptForFilters -DriveLetter $devDrive
} else {
    Write-Output "No Dev Drive found to configure."
}
