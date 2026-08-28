<#
.SYNOPSIS
    Provisions the Enterprise Banking IAM user and service account architecture.

.DESCRIPTION
    Imports employee and service-account definitions from employees.csv
    and provisions the defined Active Directory accounts.

    The script is idempotent:
    - Existing accounts are detected and skipped.
    - Missing accounts are created.
    - Existing accounts are not duplicated.

    Account types:
    - Privileged
    - Standard
    - Service

    Security controls:
    - Complex random initial password generation
    - Standard users must change password at next logon
    - Service account passwords never expire
    - Service accounts cannot change their passwords
    - Privileged and service accounts are marked AccountNotDelegated
    - Accounts are protected from accidental deletion
    - Designated RBAC security group assignment
    - Target OU validation
    - Account validation after provisioning

    IMPORTANT:
    The CSV field "PrimaryGroup" represents the designated RBAC
    security group for the account. It does not modify the native
    Active Directory primaryGroupID attribute.

    Interactive logon restrictions for service accounts are intentionally
    deferred to the later Group Policy stage.

.TARGET ENVIRONMENT
    Domain: banking.lab
    Domain Controller: AU-SYD-DC01
    Base DN: DC=banking,DC=lab
#>

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Failed to load Active Directory module."
    Write-Host "        $($_.Exception.Message)"
    exit 1
}

$DomainDN = "DC=banking,DC=lab"

# The CSV is stored in the same directory as this script.
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

$CsvPath = Join-Path `
    -Path $ScriptDirectory `
    -ChildPath "employees.csv"

# ---------------------------------------------------------------------------
# Password Generation
# ---------------------------------------------------------------------------

function New-InitialPassword {

    $Uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $Lowercase = "abcdefghijkmnopqrstuvwxyz"
    $Numbers   = "23456789"
    $Special   = "!@#$%^&*-_=+"

    $PasswordCharacters = @()

    # Guarantee complexity requirements.
    $PasswordCharacters += $Uppercase[
        (Get-Random -Minimum 0 -Maximum $Uppercase.Length)
    ]

    $PasswordCharacters += $Lowercase[
        (Get-Random -Minimum 0 -Maximum $Lowercase.Length)
    ]

    $PasswordCharacters += $Numbers[
        (Get-Random -Minimum 0 -Maximum $Numbers.Length)
    ]

    $PasswordCharacters += $Special[
        (Get-Random -Minimum 0 -Maximum $Special.Length)
    ]

    # Add additional random characters.
    $AllCharacters = $Uppercase + $Lowercase + $Numbers + $Special

    for ($i = 1; $i -le 12; $i++) {

        $PasswordCharacters += $AllCharacters[
            (Get-Random -Minimum 0 -Maximum $AllCharacters.Length)
        ]
    }

    # Randomise character order.
    $ShuffledPassword = $PasswordCharacters |
        Sort-Object { Get-Random }

    return -join $ShuffledPassword
}

# ---------------------------------------------------------------------------
# Verify CSV
# ---------------------------------------------------------------------------

if (-not (Test-Path -Path $CsvPath)) {

    Write-Host "[ERROR] Employee CSV file not found."
    Write-Host "        Expected path: $CsvPath"

    exit 1
}

# ---------------------------------------------------------------------------
# Import CSV
# ---------------------------------------------------------------------------

try {

    $Employees = Import-Csv `
        -Path $CsvPath `
        -ErrorAction Stop

    if (-not $Employees) {
        throw "CSV file contains no account records."
    }

    Write-Host ""
    Write-Host "========================================================="
    Write-Host " Enterprise Banking IAM Architecture"
    Write-Host " User / Service Account Deployment"
    Write-Host "========================================================="
    Write-Host ""

    Write-Host "[INFO] Imported $($Employees.Count) account definitions from employees.csv"
    Write-Host ""
}
catch {

    Write-Host "[ERROR] Failed to import employees.csv."
    Write-Host "        $($_.Exception.Message)"

    exit 1
}

# ---------------------------------------------------------------------------
# Provision Accounts
# ---------------------------------------------------------------------------

foreach ($Employee in $Employees) {

    try {

        # ---------------------------------------------------------------
        # Validate required CSV fields
        # ---------------------------------------------------------------

        if ([string]::IsNullOrWhiteSpace($Employee.EmployeeID)) {
            throw "EmployeeID is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.GivenName)) {
            throw "GivenName is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.Surname)) {
            throw "Surname is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.Username)) {
            throw "Username is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.AccountType)) {
            throw "AccountType is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.TargetOU)) {
            throw "TargetOU is missing."
        }

        if ([string]::IsNullOrWhiteSpace($Employee.PrimaryGroup)) {
            throw "PrimaryGroup is missing."
        }

        # ---------------------------------------------------------------
        # Normalise Target OU
        # ---------------------------------------------------------------

        $TargetOU = $Employee.TargetOU.Trim()

        # ---------------------------------------------------------------
        # Verify Target OU
        # ---------------------------------------------------------------

        try {

            Get-ADOrganizationalUnit `
                -Identity $TargetOU `
                -ErrorAction Stop |
                Out-Null
        }
        catch {

            throw "Target OU does not exist: $TargetOU"
        }

        # ---------------------------------------------------------------
        # Verify Designated RBAC Security Group
        # ---------------------------------------------------------------

        try {

            $RBACGroup = Get-ADGroup `
                -Identity $Employee.PrimaryGroup `
                -ErrorAction Stop
        }
        catch {

            throw "RBAC security group does not exist: $($Employee.PrimaryGroup)"
        }

        # ---------------------------------------------------------------
        # Validate Account Type
        # ---------------------------------------------------------------

        if ($Employee.AccountType -notin @(
            "Privileged",
            "Standard",
            "Service"
        )) {

            throw "Unsupported AccountType: $($Employee.AccountType)"
        }

        # ---------------------------------------------------------------
        # Check Existing Account
        # ---------------------------------------------------------------

        $ExistingUser = Get-ADUser `
            -Filter "SamAccountName -eq '$($Employee.Username)'" `
            -ErrorAction SilentlyContinue

        if ($ExistingUser) {

            Write-Host "[SKIP] Account already exists: $($Employee.Username)"
            Write-Host "       DN: $($ExistingUser.DistinguishedName)"

            continue
        }

        # ---------------------------------------------------------------
        # Generate Initial Password
        # ---------------------------------------------------------------

        $InitialPassword = New-InitialPassword

        $SecurePassword = ConvertTo-SecureString `
            -String $InitialPassword `
            -AsPlainText `
            -Force

        # ---------------------------------------------------------------
        # Construct Display Name
        # ---------------------------------------------------------------

        $DisplayName = "$($Employee.GivenName) $($Employee.Surname)"

        # ---------------------------------------------------------------
        # Determine Account Security Controls
        # ---------------------------------------------------------------

        $PasswordNeverExpires = $false
        $ChangePasswordAtLogon = $false
        $CannotChangePassword = $false
        $AccountNotDelegated = $false

        switch ($Employee.AccountType) {

            "Standard" {

                $ChangePasswordAtLogon = $true
            }

            "Privileged" {

                $AccountNotDelegated = $true
            }

            "Service" {

                $PasswordNeverExpires = $true
                $CannotChangePassword = $true
                $AccountNotDelegated = $true
            }
        }

        # ---------------------------------------------------------------
        # Determine Enabled State
        # ---------------------------------------------------------------

        $EnabledState = $false

        if ($Employee.Enabled.Trim().ToUpper() -eq "TRUE") {
            $EnabledState = $true
        }

        # ---------------------------------------------------------------
        # Create Active Directory Account
        # ---------------------------------------------------------------

        New-ADUser `
            -Name $DisplayName `
            -GivenName $Employee.GivenName `
            -Surname $Employee.Surname `
            -SamAccountName $Employee.Username `
            -UserPrincipalName "$($Employee.Username)@banking.lab" `
            -DisplayName $DisplayName `
            -Department $Employee.Department `
            -Title $Employee.JobTitle `
            -EmployeeID $Employee.EmployeeID `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -Enabled $EnabledState `
            -ChangePasswordAtLogon $ChangePasswordAtLogon `
            -PasswordNeverExpires $PasswordNeverExpires `
            -CannotChangePassword $CannotChangePassword `
            -AccountNotDelegated $AccountNotDelegated `
            -Description "$($Employee.AccountType) account - $($Employee.JobTitle)" `
            -ErrorAction Stop

        # ---------------------------------------------------------------
        # Assign Designated RBAC Security Group
        # ---------------------------------------------------------------

        Add-ADGroupMember `
            -Identity $RBACGroup `
            -Members $Employee.Username `
            -ErrorAction Stop

        # ---------------------------------------------------------------
        # Protect Account from Accidental Deletion
        # ---------------------------------------------------------------

        $CreatedUser = Get-ADUser `
            -Identity $Employee.Username `
            -ErrorAction Stop

        Set-ADObject `
            -Identity $CreatedUser.DistinguishedName `
            -ProtectedFromAccidentalDeletion $true `
            -ErrorAction Stop

        # ---------------------------------------------------------------
        # Output Creation Result
        # ---------------------------------------------------------------

        Write-Host "[CREATE] Account created: $($Employee.Username)"
        Write-Host "         Employee ID: $($Employee.EmployeeID)"
        Write-Host "         Account Type: $($Employee.AccountType)"
        Write-Host "         Department: $($Employee.Department)"
        Write-Host "         Target OU: $TargetOU"
        Write-Host "         RBAC Group: $($Employee.PrimaryGroup)"
        Write-Host "         Enabled: $EnabledState"

        if ($Employee.AccountType -eq "Standard") {
            Write-Host "         Password Policy: Change at next logon"
        }

        if ($Employee.AccountType -eq "Privileged") {
            Write-Host "         Account Control: AccountNotDelegated"
        }

        if ($Employee.AccountType -eq "Service") {
            Write-Host "         Password Policy: Never expires"
            Write-Host "         Password Change: Not permitted"
            Write-Host "         Account Control: AccountNotDelegated"
            Write-Host "         Interactive Logon Restriction: Deferred to GPO stage"
        }

        Write-Host "         Accidental Deletion Protection: Enabled"
        Write-Host "         Initial Password: Generated and not displayed"
    }
    catch {

        Write-Host "[ERROR] Failed to provision account: $($Employee.Username)"
        Write-Host "        $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Deployment Completion
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================================="
Write-Host " Account deployment completed."
Write-Host "========================================================="
Write-Host ""

# ---------------------------------------------------------------------------
# Programmatic Validation
# ---------------------------------------------------------------------------

Write-Host "Account Validation"
Write-Host "---------------------------------------------------------"

$ValidationFailures = 0

foreach ($Employee in $Employees) {

    try {

        # ---------------------------------------------------------------
        # Retrieve account
        # ---------------------------------------------------------------

        $ValidationUser = Get-ADUser `
            -Identity $Employee.Username `
            -Properties `
                Enabled,
                Department,
                Title,
                EmployeeID,
                DistinguishedName,
                PasswordNeverExpires,
                CannotChangePassword,
                AccountNotDelegated,
                ProtectedFromAccidentalDeletion `
            -ErrorAction Stop

        # ---------------------------------------------------------------
        # Validate expected OU
        # ---------------------------------------------------------------

        $ExpectedOU = $Employee.TargetOU.Trim()

        if ($ValidationUser.DistinguishedName -notlike "*,$ExpectedOU") {

            throw "Account is not located in expected OU: $ExpectedOU"
        }

        # ---------------------------------------------------------------
        # Validate RBAC group membership
        # ---------------------------------------------------------------

        $ValidationGroups = Get-ADPrincipalGroupMembership `
            -Identity $ValidationUser `
            -ErrorAction Stop

        $RBACMembership = $ValidationGroups |
            Where-Object {
                $_.Name -eq $Employee.PrimaryGroup
            }

        if (-not $RBACMembership) {

            throw "Designated RBAC group membership missing: $($Employee.PrimaryGroup)"
        }

        # ---------------------------------------------------------------
        # Validate account type-specific controls
        # ---------------------------------------------------------------

        switch ($Employee.AccountType) {

            "Standard" {

                if (-not $ValidationUser.Enabled) {
                    throw "Standard account is disabled."
                }
            }

            "Privileged" {

                if (-not $ValidationUser.AccountNotDelegated) {
                    throw "Privileged account is not marked AccountNotDelegated."
                }
            }

            "Service" {

                if (-not $ValidationUser.PasswordNeverExpires) {
                    throw "Service account PasswordNeverExpires is not enabled."
                }

                if (-not $ValidationUser.CannotChangePassword) {
                    throw "Service account CannotChangePassword is not enabled."
                }

                if (-not $ValidationUser.AccountNotDelegated) {
                    throw "Service account is not marked AccountNotDelegated."
                }
            }
        }

        # ---------------------------------------------------------------
        # Validate accidental deletion protection
        # ---------------------------------------------------------------

        if (-not $ValidationUser.ProtectedFromAccidentalDeletion) {

            throw "Accidental deletion protection is not enabled."
        }

        # ---------------------------------------------------------------
        # Validation successful
        # ---------------------------------------------------------------

        Write-Host "[VALID] $($Employee.Username)"
        Write-Host "        Type: $($Employee.AccountType)"
        Write-Host "        OU: $($ValidationUser.DistinguishedName)"
        Write-Host "        RBAC Group: $($Employee.PrimaryGroup)"
        Write-Host "        Accidental Deletion Protection: Enabled"

    }
    catch {

        Write-Host "[INVALID] $($Employee.Username)"
        Write-Host "          $($_.Exception.Message)"

        $ValidationFailures++
    }
}

# ---------------------------------------------------------------------------
# Validation Summary
# ---------------------------------------------------------------------------

Write-Host ""

if ($ValidationFailures -eq 0) {

    Write-Host "========================================================="
    Write-Host " Account validation completed successfully."
    Write-Host " Validation failures: 0"
    Write-Host "========================================================="
}
else {

    Write-Host "========================================================="
    Write-Host " Account validation completed with $ValidationFailures failure(s)."
    Write-Host "========================================================="
}