# Function to check if a drive is a Dev Drive
function Get-DevDrive {
    $devDrives = Get-Volume | Where-Object { $_.FileSystemType -eq 'ReFS' -and $_.DriveType -eq 'Fixed' }
    $devDriveLetters = @()

    foreach ($drive in $devDrives) {
        $driveLetter = "$($drive.DriveLetter):"
        Write-Host "`nDev Drive found: $driveLetter"
        $devDriveLetters += $driveLetter
    }

    switch ($devDriveLetters.Count) {
        0 {
            Write-Output "No Dev Drive found on the system."
            return $null
        }
        1 {
            return $devDriveLetters[0]
        }
        default {
            Write-Host "Multiple Dev Drives found:"
            for ($i = 0; $i -lt $devDriveLetters.Count; $i++) {
                Write-Host "[$i] $($devDriveLetters[$i])"
            }
            while ($true) {
                $selection = Read-Host "Please select the drive you want to configure by entering the corresponding number"
                if ($selection -match '^\d+$' -and [int]$selection -lt $devDriveLetters.Count) {
                    return $devDriveLetters[$selection]
                } else {
                    Write-Host "Invalid selection. Please enter a valid number."
                }
            }
        }
    }
}

# Main script to set up the Environment Variables for Package Cache

# Retrieve the Dev Drive
$selectedDrive = Get-DevDrive
if ($selectedDrive) {
    Write-Host "Selected Dev Drive: $selectedDrive`n"
} else {
    Write-Host "No valid Dev Drive selected. Exiting script."
    exit 1
}

# Define the Dev Drive base path
$DevDrive = "$selectedDrive\packages"

# Function to create a directory if it doesn't exist
function New-DirectoryIfNotExists {
    param (
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force
        Write-Output "Created directory: $Path"
    } else {
        Write-Output "Directory already exists: $Path"
    }
}

# Function to set a user environment variable with verbose output
function Set-UserEnvironmentVariable {
    param (
        [string]$Name,
        [string]$Value
    )
    $currentValue = [System.Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)
    if ($currentValue -eq $Value) {
        Write-Output "Environment variable '$Name' is already set to '$Value'. No further setup is required."
    } else {
        try {
            $output = setx $Name $Value
            if ($output -match "SUCCESS: Specified value was saved.") {
                Write-Output "SUCCESS: Environment variable '$Name' was set to '$Value'."
            } else {
                Write-Output "ERROR: Could not set environment variable '$Name'. Message: $output"
            }
        } catch {
            Write-Output "ERROR: Access to the registry path is denied for environment variable '$Name'."
        }
    }
}

# Function to move contents from one directory to another
function Move-CacheContents {
    param (
        [string]$SourcePath,
        [string]$DestinationPath
    )
    if (Test-Path -Path $SourcePath) {
        Move-Item -Path "$SourcePath\*" -Destination $DestinationPath -Force
        Remove-Item -Path $SourcePath -Recurse -Force
        Write-Output "Moved contents from '$SourcePath' to '$DestinationPath' and removed the old directory."
    } else {
        Write-Output "No contents to move from '$SourcePath'."
    }
}

# Create necessary directories
$directories = @(
    "$DevDrive\npm",
    "$DevDrive\$env:USERNAME\.nuget\packages",
    "$DevDrive\vcpkg",
    "$DevDrive\pip",
    "$DevDrive\cargo",
    "$DevDrive\maven",
    "$DevDrive\gradle"
)

Write-Output "### Directory Setup ###"
foreach ($dir in $directories) {
    New-DirectoryIfNotExists -Path $dir
}
Write-Output ""

# Environment variable setup and cache moving
$cacheSettings = @(
    @{ Name = "npm_config_cache"; Value = "$DevDrive\npm"; SourcePaths = @("$env:APPDATA\npm-cache", "$env:LOCALAPPDATA\npm-cache") },
    @{ Name = "NUGET_PACKAGES"; Value = "$DevDrive\$env:USERNAME\.nuget\packages"; SourcePaths = @("$env:USERPROFILE\.nuget\packages") },
    @{ Name = "VCPKG_DEFAULT_BINARY_CACHE"; Value = "$DevDrive\vcpkg"; SourcePaths = @("$env:LOCALAPPDATA\vcpkg\archives", "$env:APPDATA\vcpkg\archives") },
    @{ Name = "PIP_CACHE_DIR"; Value = "$DevDrive\pip"; SourcePaths = @("$env:LOCALAPPDATA\pip\Cache") },
    @{ Name = "CARGO_HOME"; Value = "$DevDrive\cargo"; SourcePaths = @("$env:USERPROFILE\.cargo") },
    @{ Name = "GRADLE_USER_HOME"; Value = "$DevDrive\gradle"; SourcePaths = @("$env:USERPROFILE\.gradle") }
)

foreach ($setting in $cacheSettings) {
    Write-Output "### Setting up $($setting.Name) ###"
    Set-UserEnvironmentVariable -Name $setting.Name -Value $setting.Value
    foreach ($source in $setting.SourcePaths) {
        Move-CacheContents -SourcePath $source -DestinationPath $setting.Value
    }
    Write-Output ""
}

# Additional step to set MAVEN_OPTS and move Maven repository
Write-Output "### Setting up MAVEN_OPTS ###"
$mavenRepoLocal = "$DevDrive\maven"
New-DirectoryIfNotExists -Path $mavenRepoLocal
$mavenOpts = [System.Environment]::GetEnvironmentVariable('MAVEN_OPTS', [System.EnvironmentVariableTarget]::User)
$escapedMavenRepoLocal = [regex]::Escape($mavenRepoLocal)
if ($mavenOpts -notmatch "-Dmaven\.repo\.local=$escapedMavenRepoLocal") {
    $newMavenOpts = "-Dmaven.repo.local=$mavenRepoLocal $mavenOpts"
    Set-UserEnvironmentVariable -Name "MAVEN_OPTS" -Value $newMavenOpts
    Write-Output "Environment variable 'MAVEN_OPTS' set to: $newMavenOpts"
} else {
    Write-Output "Environment variable 'MAVEN_OPTS' is already set correctly. No further setup is required."
}
Move-CacheContents -SourcePath "$env:USERPROFILE\.m2\repository" -DestinationPath $mavenRepoLocal
Write-Output ""

# Optional: Move TMP and TEMP to Dev Drive if not already on Dev Drive
Write-Output "### Setting up TMP and TEMP ###"
$currentTemp = [System.Environment]::GetEnvironmentVariable('TEMP', [System.EnvironmentVariableTarget]::User)
$currentTmp = [System.Environment]::GetEnvironmentVariable('TMP', [System.EnvironmentVariableTarget]::User)

if (($currentTemp -notlike "$selectedDrive*") -or ($currentTmp -notlike "$selectedDrive*")) {
    $confirmMoveTemp = Read-Host "Do you want to move TMP and TEMP directories to the Dev Drive? (y/n)"
    if ($confirmMoveTemp -eq 'y') {
        $tempPath = "$selectedDrive\temp"
        New-DirectoryIfNotExists -Path $tempPath
        Set-UserEnvironmentVariable -Name "TEMP" -Value $tempPath
        Set-UserEnvironmentVariable -Name "TMP" -Value $tempPath
        Write-Output "Environment variables 'TEMP' and 'TMP' set to: $tempPath"
    } else {
        Write-Output "Skipping move of TMP and TEMP directories."
    }
} else {
    Write-Output "TEMP and TMP are already set to the Dev Drive."
}

Write-Output ""
Write-Output "### Setup Complete ###"
Write-Output "Package cache on Dev Drive was set successfully."
