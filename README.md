# Dev Drive Scripts 📜

This repository contains PowerShell scripts designed to assist with setting up and administering a Development Drive (Dev Drive) on Windows 11. The Dev Drive is intended to enhance performance and efficiency for development-related tasks by utilizing the Resilient File System (ReFS).

## Scripts

### 1. 💽 `SetupDevDrive.ps1`

This script sets up the Dev Drive by configuring trust settings, antivirus filters, and file system filters. It includes the following key functions:

#### `Test-DevDriveTrusted`

- Tests if the Dev Drive is trusted.

#### `ManageAntiVirusFilter`

- Manages the antivirus filter setting on the Dev Drive.

#### `Get-DevDriveAllowedFilters`

- Retrieves allowed filters on the Dev Drive.

#### `Add-DevDriveFilters`

- Adds specified filters to the Dev Drive.

#### `PromptForFilters`

- Prompts the user to add default or custom filters to the Dev Drive.

### 2. 👤 `SetDevDriveOwner.ps1`

This script configures ownership and permissions for a Dev Drive. It includes the following functions:

#### `Set-DevDrivePermissions`

- Sets full control permissions for the current user on the specified Dev Drive.
- Hides the Dev Drive from other users by modifying the registry.

#### `Test-DevDrivePermissions`

- Reviews and displays the current permissions for the specified Dev Drive.

### 3. 📦 `SetupDevDrivePackageCache.ps1`

This script sets up environment variables for package caches and moves existing caches to the Dev Drive. It includes the following functions:

#### `New-DirectoryIfNotExists`

- Creates a directories if they doesn't exist.

#### `Set-UserEnvironmentVariable`

- Sets user environment variables with verbose output.

#### `Move-CacheContents`

- Moves cache contents from source to destination directories.

### 4. 🚫 `UnsetDevDriveOwner.ps1`

This script reverts the ownership and permissions changes made by `SetDevDriveOwner.ps1`. It includes the following functions:

#### `Remove-DevDrivePermissions`

- Removes the full control permissions for the current user on the specified Dev Drive.
- Restores the visibility of the Dev Drive for other users by modifying the registry.

#### `Test-DevDrivePermissions`

- Reviews and displays the current permissions for the specified Dev Drive.
