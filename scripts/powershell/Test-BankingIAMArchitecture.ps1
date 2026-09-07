<#
.SYNOPSIS
    Performs read-only security assurance of the Enterprise Banking IAM
    Architecture deployed in banking.lab.

.DESCRIPTION
    Validates the completed Active Directory IAM architecture against the
    approved expected state established by the project configuration,
    provisioning data, deployment scripts and implemented security controls.

    The script does not provision, remediate, move, create, delete or modify
    Active Directory, Group Policy or host security configuration.

    Validation domains include:
    - Organisational Unit architecture
    - Controlled identity population
    - Identity classification and placement
    - RBAC security-group architecture and membership
    - Administrative tier separation
    - Privileged-account security controls
    - Service-account security controls
    - Group Policy existence, linkage and precedence
    - Domain password and account-lockout policy
    - LDAP signing
    - Effective interactive-logon restrictions
    - Tier 0 administrative protection
    - Remote Desktop exposure
    - Declarative provisioning integrity
    - Overall IAM architecture conformance

    NOTE:
    Effective User Rights Assignment validation uses secedit.exe to export
    the current effective policy to a temporary local file. This does not
    change the security configuration. The temporary file is removed after
    validation.

.TARGET ENVIRONMENT
    Domain: banking.lab
    Domain Controller: AU-SYD-DC01
    Base DN: DC=banking,DC=lab

.NOTES
    This is an assurance script, not a remediation script.

    No state-changing Active Directory or Group Policy commands should be
    introduced into this file.
#>

[CmdletBinding()]
param (
    [ValidateSet(
        "All",
        "Architecture",
        "Security",
        "Summary"
    )]
    [string]$View = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

$DomainName = "banking.lab"
$DomainDN   = "DC=banking,DC=lab"
$ExpectedDC = "AU-SYD-DC01"

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPath = Join-Path -Path $ScriptDirectory -ChildPath "employees.csv"

# ---------------------------------------------------------------------------
# Validation Result Collection
# ---------------------------------------------------------------------------

$ValidationResults = [System.Collections.Generic.List[object]]::new()

function Add-ValidationResult {

    param (
        [Parameter(Mandatory)]
        [string]$ID,

        [Parameter(Mandatory)]
        [string]$Domain,

        [Parameter(Mandatory)]
        [ValidateSet("PASS", "FAIL", "WARN")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Detail
    )

    $ValidationResults.Add(
        [PSCustomObject]@{
            ID     = $ID
            Domain = $Domain
            Status = $Status
            Detail = $Detail
        }
    )
}

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

function Test-StringSetEqual {

    param (
        [string[]]$Expected,
        [string[]]$Actual
    )

    $ExpectedNormalised = @(
        $Expected |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )

    $ActualNormalised = @(
        $Actual |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )

    if ($ExpectedNormalised.Count -ne $ActualNormalised.Count) {
        return $false
    }

    foreach ($Item in $ExpectedNormalised) {

        if ($Item -notin $ActualNormalised) {
            return $false
        }
    }

    return $true
}


function Get-ParentDistinguishedName {

    param (
        [Parameter(Mandatory)]
        [string]$DistinguishedName
    )

    $CommaIndex = $DistinguishedName.IndexOf(",")

    if ($CommaIndex -lt 0) {
        return ""
    }

    return $DistinguishedName.Substring($CommaIndex + 1)
}


function Convert-PrincipalTokenToName {

    param (
        [Parameter(Mandatory)]
        [string]$Token
    )

    $CleanToken = $Token.Trim()

    if ($CleanToken.StartsWith("*")) {
        $CleanToken = $CleanToken.Substring(1)
    }

    if ($CleanToken -match "^S-\d-\d+") {

        try {
            $Sid = [System.Security.Principal.SecurityIdentifier]::new(
                $CleanToken
            )

            $Account = $Sid.Translate(
                [System.Security.Principal.NTAccount]
            )

            return $Account.Value
        }
        catch {
            return $CleanToken
        }
    }

    return $CleanToken
}


function Get-PrincipalLeafName {

    param (
        [Parameter(Mandatory)]
        [string]$Principal
    )

    $Normalised = Convert-PrincipalTokenToName -Token $Principal

    if ($Normalised.Contains("\")) {
        return ($Normalised -split "\\")[-1]
    }

    return $Normalised
}


function Get-EffectiveUserRights {

    $TempFile = Join-Path `
        -Path $env:TEMP `
        -ChildPath "banking-iam-user-rights-$PID.inf"

    try {

        & secedit.exe `
            /export `
            /cfg $TempFile `
            /areas USER_RIGHTS `
            /quiet

        if ($LASTEXITCODE -ne 0) {
            throw "secedit.exe returned exit code $LASTEXITCODE."
        }

        if (-not (Test-Path -Path $TempFile)) {
            throw "Effective security-policy export was not created."
        }

        $Rights = @{}

        foreach ($Line in Get-Content -Path $TempFile) {

            if ($Line -notmatch "=") {
                continue
            }

            $Parts = $Line -split "=", 2

            $RightName = $Parts[0].Trim()
            $RawValue  = $Parts[1].Trim()

            if ([string]::IsNullOrWhiteSpace($RawValue)) {
                $Rights[$RightName] = @()
                continue
            }

            $Principals = @(
                $RawValue -split "," |
                    ForEach-Object {
                        Get-PrincipalLeafName -Principal $_
                    }
            )

            $Rights[$RightName] = $Principals
        }

        return $Rights
    }
    finally {

        if (Test-Path -Path $TempFile) {
            Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
        }
    }
}


function Get-DirectGpoLink {

    param (
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$GpoName
    )

    $Inheritance = Get-GPInheritance `
        -Target $Target `
        -ErrorAction Stop

    $Matches = @(
        $Inheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $GpoName
            }
    )

    if ($Matches.Count -ne 1) {
        return $null
    }

    return $Matches[0]
}


function Test-GpoLinkEnabled {

    param (
        [Parameter(Mandatory)]
        [object]$Link
    )

    if ($null -eq $Link) {
        return $false
    }

    $Value = $Link.Enabled.ToString()

    return $Value -in @(
        "True",
        "Yes"
    )
}

# ---------------------------------------------------------------------------
# Expected OU Architecture
# ---------------------------------------------------------------------------

$ExpectedOUs = @(
    @{
        Name = "Tier0_Identity_Infrastructure"
        DN   = "OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "Domain_Controllers"
        DN   = "OU=Domain_Controllers,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "Privileged_Accounts"
        DN   = "OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "Administrative_Groups"
        DN   = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "Tier1_Server_Infrastructure"
        DN   = "OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "Infrastructure_Servers"
        DN   = "OU=Infrastructure_Servers,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "Application_Servers"
        DN   = "OU=Application_Servers,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "Server_Admins"
        DN   = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "Tier2_User_Computing"
        DN   = "OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "Workstations"
        DN   = "OU=Workstations,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "Corporate_Users"
        DN   = "OU=Corporate_Users,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "Department_Groups"
        DN   = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "Desktop_Support"
        DN   = "OU=Desktop_Support,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "Service_Accounts"
        DN   = "OU=Service_Accounts,$DomainDN"
    }
)

# ---------------------------------------------------------------------------
# Expected RBAC Architecture
# ---------------------------------------------------------------------------

$ExpectedGroups = @(
    @{
        Name = "GG-T0-AD-Administrators"
        OU   = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T0-Domain-Controllers"
        OU   = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T0-Identity-Operations"
        OU   = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T1-Server-Administrators"
        OU   = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T1-Infrastructure-Administrators"
        OU   = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T1-Application-Administrators"
        OU   = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name = "GG-T2-Desktop-Support"
        OU   = "OU=Desktop_Support,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "GG-Department-Finance"
        OU   = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "GG-Department-HR"
        OU   = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "GG-Department-IT"
        OU   = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name = "GG-Department-Operations"
        OU   = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    }
)

$ProjectGroupNames = @(
    $ExpectedGroups |
        ForEach-Object { $_.Name }
)

# ---------------------------------------------------------------------------
# Expected Privileged Architecture
# ---------------------------------------------------------------------------

$ExpectedTierMembership = @{
    "adm.jc.olfato"   = "GG-T0-AD-Administrators"
    "adm.syd.srv01"   = "GG-T1-Server-Administrators"
    "adm.syd.help01"  = "GG-T2-Desktop-Support"
}

$TierAdministrativeGroups = @(
    "GG-T0-AD-Administrators",
    "GG-T0-Domain-Controllers",
    "GG-T0-Identity-Operations",
    "GG-T1-Server-Administrators",
    "GG-T1-Infrastructure-Administrators",
    "GG-T1-Application-Administrators",
    "GG-T2-Desktop-Support"
)

$ServiceAccounts = @(
    "svc-sql-banking",
    "svc-sentinel-log",
    "svc-app-portal"
)

# ---------------------------------------------------------------------------
# Expected GPO Architecture
# ---------------------------------------------------------------------------

$DomainControllersOU = "OU=Domain Controllers,$DomainDN"

$WorkstationsOU = `
    "OU=Workstations,OU=Tier2_User_Computing,$DomainDN"

$RequiredGpos = @(
    "Default Domain Policy",
    "DC Security Hardening",
    "Default Domain Controllers Policy",
    "GPO-SEC-T0-Administrative-Restrictions",
    "GPO-SEC-Service-Account-Restrictions"
)

$ExpectedDCGpoOrder = @(
    @{
        Name  = "DC Security Hardening"
        Order = 1
    },
    @{
        Name  = "Default Domain Controllers Policy"
        Order = 2
    },
    @{
        Name  = "GPO-SEC-T0-Administrative-Restrictions"
        Order = 3
    },
    @{
        Name  = "GPO-SEC-Service-Account-Restrictions"
        Order = 4
    }
)

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "=============================================================="
Write-Host " Enterprise Banking IAM Architecture Validation"
Write-Host "=============================================================="
Write-Host ""

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Required PowerShell module could not be loaded."
    Write-Host "        $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path -Path $CsvPath)) {
    Write-Host "[ERROR] employees.csv was not found."
    Write-Host "        Expected path: $CsvPath"
    exit 1
}

$CurrentComputer = $env:COMPUTERNAME

if ($CurrentComputer -ne $ExpectedDC) {
    Write-Host "[ERROR] Validation must be executed on $ExpectedDC."
    Write-Host "        Current computer: $CurrentComputer"
    exit 1
}

try {

    $CurrentDomain = Get-ADDomain -ErrorAction Stop

    if ($CurrentDomain.DNSRoot -ne $DomainName) {
        throw "Current domain is $($CurrentDomain.DNSRoot), expected $DomainName."
    }
}
catch {
    Write-Host "[ERROR] Domain preflight validation failed."
    Write-Host "        $($_.Exception.Message)"
    exit 1
}

try {

    $Employees = @(Import-Csv -Path $CsvPath -ErrorAction Stop)

    if ($Employees.Count -eq 0) {
        throw "employees.csv contains no records."
    }
}
catch {
    Write-Host "[ERROR] Failed to import employees.csv."
    Write-Host "        $($_.Exception.Message)"
    exit 1
}

# ===========================================================================
# IAM-VAL-01 — OU Architecture
# ===========================================================================

try {

    $Failures = @()

    foreach ($ExpectedOU in $ExpectedOUs) {

        try {

            $OU = Get-ADOrganizationalUnit `
                -Identity $ExpectedOU.DN `
                -Properties ProtectedFromAccidentalDeletion `
                -ErrorAction Stop

            if (-not $OU.ProtectedFromAccidentalDeletion) {
                $Failures += "$($ExpectedOU.Name): deletion protection disabled"
            }
        }
        catch {
            $Failures += "$($ExpectedOU.Name): missing"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-01" `
            -Domain "OU Architecture" `
            -Status "PASS" `
            -Detail "14/14 required OUs exist at the expected DNs with accidental-deletion protection enabled."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-01" `
            -Domain "OU Architecture" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-01" `
        -Domain "OU Architecture" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-02 — Identity Population
# ===========================================================================

try {

    $ExpectedUsernames = @(
        $Employees.Username |
            Sort-Object -Unique
    )

    $IdentityOUs = @(
        "OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,$DomainDN",
        "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN",
        "OU=Desktop_Support,OU=Tier2_User_Computing,$DomainDN",
        "OU=Corporate_Users,OU=Tier2_User_Computing,$DomainDN",
        "OU=Service_Accounts,$DomainDN"
    )

    $ActualProjectUsers = @()

    foreach ($IdentityOU in $IdentityOUs) {

        $ActualProjectUsers += Get-ADUser `
            -Filter * `
            -SearchBase $IdentityOU `
            -SearchScope OneLevel `
            -ErrorAction Stop
    }

    $ActualUsernames = @(
        $ActualProjectUsers.SamAccountName |
            Sort-Object -Unique
    )

    if (
        $Employees.Count -eq 10 -and
        $ExpectedUsernames.Count -eq 10 -and
        (Test-StringSetEqual `
            -Expected $ExpectedUsernames `
            -Actual $ActualUsernames)
    ) {

        Add-ValidationResult `
            -ID "IAM-VAL-02" `
            -Domain "Identity Population" `
            -Status "PASS" `
            -Detail "10/10 controlled project identities exist with no additional user objects in the controlled identity OUs."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-02" `
            -Domain "Identity Population" `
            -Status "FAIL" `
            -Detail "Controlled identity population does not exactly match the 10-identity declarative dataset."
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-02" `
        -Domain "Identity Population" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-03 — Identity Classification and Placement
# ===========================================================================

try {

    $Failures = @()

    foreach ($Employee in $Employees) {

        try {

            $User = Get-ADUser `
                -Identity $Employee.Username `
                -Properties `
                    GivenName,
                    Surname,
                    DisplayName,
                    UserPrincipalName,
                    Department,
                    Title,
                    EmployeeID,
                    Enabled `
                -ErrorAction Stop

            $ExpectedDisplayName = `
                "$($Employee.GivenName) $($Employee.Surname)"

            $ExpectedUPN = `
                "$($Employee.Username)@$DomainName"

            $ActualParent = Get-ParentDistinguishedName `
                -DistinguishedName $User.DistinguishedName

            if ($ActualParent -ne $Employee.TargetOU.Trim()) {
                $Failures += "$($Employee.Username): incorrect OU"
            }

            if ($User.GivenName -ne $Employee.GivenName) {
                $Failures += "$($Employee.Username): GivenName mismatch"
            }

            if ($User.Surname -ne $Employee.Surname) {
                $Failures += "$($Employee.Username): Surname mismatch"
            }

            if ($User.DisplayName -ne $ExpectedDisplayName) {
                $Failures += "$($Employee.Username): DisplayName mismatch"
            }

            if ($User.UserPrincipalName -ne $ExpectedUPN) {
                $Failures += "$($Employee.Username): UPN mismatch"
            }

            if ($User.Department -ne $Employee.Department) {
                $Failures += "$($Employee.Username): Department mismatch"
            }

            if ($User.Title -ne $Employee.JobTitle) {
                $Failures += "$($Employee.Username): Title mismatch"
            }

            if ($User.EmployeeID -ne $Employee.EmployeeID) {
                $Failures += "$($Employee.Username): EmployeeID mismatch"
            }

            $ExpectedEnabled = `
                ($Employee.Enabled.Trim().ToUpper() -eq "TRUE")

            if ([bool]$User.Enabled -ne $ExpectedEnabled) {
                $Failures += "$($Employee.Username): Enabled-state mismatch"
            }
        }
        catch {
            $Failures += "$($Employee.Username): $($_.Exception.Message)"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-03" `
            -Domain "Identity Classification" `
            -Status "PASS" `
            -Detail "All 10 identities match their declarative OU placement and core directory attributes."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-03" `
            -Domain "Identity Classification" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-03" `
        -Domain "Identity Classification" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-04 — RBAC Architecture and Membership
# ===========================================================================

try {

    $Failures = @()

    foreach ($ExpectedGroup in $ExpectedGroups) {

        $Matches = @(
            Get-ADGroup `
                -Filter "Name -eq '$($ExpectedGroup.Name)'" `
                -Properties GroupScope, GroupCategory, DistinguishedName `
                -ErrorAction Stop
        )

        if ($Matches.Count -ne 1) {

            $Failures += `
                "$($ExpectedGroup.Name): expected one group, found $($Matches.Count)"

            continue
        }

        $Group = $Matches[0]

        if ($Group.GroupScope -ne "Global") {
            $Failures += "$($ExpectedGroup.Name): scope is not Global"
        }

        if ($Group.GroupCategory -ne "Security") {
            $Failures += "$($ExpectedGroup.Name): category is not Security"
        }

        $ActualParent = Get-ParentDistinguishedName `
            -DistinguishedName $Group.DistinguishedName

        if ($ActualParent -ne $ExpectedGroup.OU) {
            $Failures += "$($ExpectedGroup.Name): incorrect OU"
        }
    }

    foreach ($Employee in $Employees) {

        $UserGroups = @(
            Get-ADPrincipalGroupMembership `
                -Identity $Employee.Username `
                -ErrorAction Stop |
            Where-Object {
                $_.Name -in $ProjectGroupNames
            } |
            Select-Object -ExpandProperty Name
        )

        $ExpectedMembership = @(
            $Employee.PrimaryGroup
        )

        if (-not (
            Test-StringSetEqual `
                -Expected $ExpectedMembership `
                -Actual $UserGroups
        )) {

            $Failures += `
                "$($Employee.Username): project RBAC membership does not equal $($Employee.PrimaryGroup)"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-04" `
            -Domain "RBAC" `
            -Status "PASS" `
            -Detail "11/11 project RBAC groups conform and all controlled identities have exactly their designated project RBAC membership."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-04" `
            -Domain "RBAC" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-04" `
        -Domain "RBAC" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-05 — Privileged Tiering
# ===========================================================================

try {

    $Failures = @()

    foreach ($Account in $ExpectedTierMembership.Keys) {

        $ExpectedTierGroup = $ExpectedTierMembership[$Account]

        $ActualTierGroups = @(
            Get-ADPrincipalGroupMembership `
                -Identity $Account `
                -ErrorAction Stop |
            Where-Object {
                $_.Name -in $TierAdministrativeGroups
            } |
            Select-Object -ExpandProperty Name
        )

        if (-not (
            Test-StringSetEqual `
                -Expected @($ExpectedTierGroup) `
                -Actual $ActualTierGroups
        )) {

            $Failures += `
                "$($Account): administrative-tier membership does not equal $ExpectedTierGroup"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-05" `
            -Domain "Privileged Tiering" `
            -Status "PASS" `
            -Detail "Tier 0, Tier 1 and Tier 2 controlled administrative identities remain separated with no project cross-tier membership."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-05" `
            -Domain "Privileged Tiering" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-05" `
        -Domain "Privileged Tiering" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-06 — Privileged Account Controls
# ===========================================================================

try {

    $Failures = @()

    $PrivilegedEmployees = @(
        $Employees |
            Where-Object {
                $_.AccountType -eq "Privileged"
            }
    )

    foreach ($Employee in $PrivilegedEmployees) {

        $User = Get-ADUser `
            -Identity $Employee.Username `
            -Properties `
                Enabled,
                PasswordNeverExpires,
                CannotChangePassword,
                AccountNotDelegated,
                ProtectedFromAccidentalDeletion `
            -ErrorAction Stop

        if (-not $User.Enabled) {
            $Failures += "$($Employee.Username): disabled"
        }

        if (-not $User.AccountNotDelegated) {
            $Failures += "$($Employee.Username): AccountNotDelegated disabled"
        }

        if ($User.PasswordNeverExpires) {
            $Failures += "$($Employee.Username): PasswordNeverExpires unexpectedly enabled"
        }

        if ($User.CannotChangePassword) {
            $Failures += "$($Employee.Username): CannotChangePassword unexpectedly enabled"
        }

        if (-not $User.ProtectedFromAccidentalDeletion) {
            $Failures += "$($Employee.Username): deletion protection disabled"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-06" `
            -Domain "Privileged Account Controls" `
            -Status "PASS" `
            -Detail "3/3 privileged identities retain the approved persistent account security controls."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-06" `
            -Domain "Privileged Account Controls" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-06" `
        -Domain "Privileged Account Controls" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-07 — Service Account Controls
# ===========================================================================

try {

    $Failures = @()

    $ServiceEmployees = @(
        $Employees |
            Where-Object {
                $_.AccountType -eq "Service"
            }
    )

    foreach ($Employee in $ServiceEmployees) {

        $User = Get-ADUser `
            -Identity $Employee.Username `
            -Properties `
                Enabled,
                PasswordNeverExpires,
                CannotChangePassword,
                AccountNotDelegated,
                ProtectedFromAccidentalDeletion `
            -ErrorAction Stop

        if (-not $User.Enabled) {
            $Failures += "$($Employee.Username): disabled"
        }

        if (-not $User.PasswordNeverExpires) {
            $Failures += "$($Employee.Username): PasswordNeverExpires disabled"
        }

        if (-not $User.CannotChangePassword) {
            $Failures += "$($Employee.Username): CannotChangePassword disabled"
        }

        if (-not $User.AccountNotDelegated) {
            $Failures += "$($Employee.Username): AccountNotDelegated disabled"
        }

        if (-not $User.ProtectedFromAccidentalDeletion) {
            $Failures += "$($Employee.Username): deletion protection disabled"
        }
    }

    if (
        $ServiceEmployees.Count -eq 3 -and
        $Failures.Count -eq 0
    ) {

        Add-ValidationResult `
            -ID "IAM-VAL-07" `
            -Domain "Service Accounts" `
            -Status "PASS" `
            -Detail "3/3 service identities retain the approved non-human account security controls."
    }
    else {

        if ($ServiceEmployees.Count -ne 3) {
            $Failures += `
                "Expected 3 service identities, found $($ServiceEmployees.Count)"
        }

        Add-ValidationResult `
            -ID "IAM-VAL-07" `
            -Domain "Service Accounts" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-07" `
        -Domain "Service Accounts" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-08 — GPO Architecture
# ===========================================================================

try {

    $Failures = @()

    # -----------------------------------------------------------------------
    # Required GPO existence
    # -----------------------------------------------------------------------

    foreach ($GpoName in $RequiredGpos) {

        $Matches = @(
            Get-GPO -All |
                Where-Object {
                    $_.DisplayName -eq $GpoName
                }
        )

        if ($Matches.Count -eq 0) {

            $Failures += "$($GpoName): missing"
            continue
        }

        if ($Matches.Count -gt 1) {

            $Failures += "$($GpoName): multiple GPOs with the same display name detected"
        }
    }

    # -----------------------------------------------------------------------
    # Default Domain Policy — direct domain link
    # -----------------------------------------------------------------------

    $DomainLink = Get-DirectGpoLink `
        -Target $DomainDN `
        -GpoName "Default Domain Policy"

    if ($null -eq $DomainLink) {

        $Failures += "Default Domain Policy: direct domain link missing or ambiguous"
    }
    elseif (-not (Test-GpoLinkEnabled -Link $DomainLink)) {

        $Failures += "Default Domain Policy: domain link is disabled"
    }

    # -----------------------------------------------------------------------
    # Domain Controllers OU — required direct links
    # -----------------------------------------------------------------------

    $RequiredDCLinks = @(
        "DC Security Hardening",
        "Default Domain Controllers Policy",
        "GPO-SEC-T0-Administrative-Restrictions",
        "GPO-SEC-Service-Account-Restrictions"
    )

    foreach ($GpoName in $RequiredDCLinks) {

        $Link = Get-DirectGpoLink `
            -Target $DomainControllersOU `
            -GpoName $GpoName

        if ($null -eq $Link) {

            $Failures += "$($GpoName): DC OU link missing or ambiguous"
            continue
        }

        if (-not (Test-GpoLinkEnabled -Link $Link)) {

            $Failures += "$($GpoName): DC OU link disabled"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-08" `
            -Domain "GPO Architecture" `
            -Status "PASS" `
            -Detail "Required GPOs exist. Default Domain Policy is linked at domain scope and the four approved Domain Controllers GPOs are directly linked and enabled."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-08" `
            -Domain "GPO Architecture" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-08" `
        -Domain "GPO Architecture" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-09 — GPO Precedence
# ===========================================================================

try {

    $Failures = @()

    $DCInheritance = Get-GPInheritance `
        -Target $DomainControllersOU `
        -ErrorAction Stop

    $ActualDCLinks = @(
        $DCInheritance.GpoLinks |
            Sort-Object Order
    )

    if ($ActualDCLinks.Count -ne $ExpectedDCGpoOrder.Count) {

        $Failures += `
            "Expected $($ExpectedDCGpoOrder.Count) direct Domain Controllers GPO links, found $($ActualDCLinks.Count)"
    }

    foreach ($ExpectedLink in $ExpectedDCGpoOrder) {

        $ActualLink = $DCInheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $ExpectedLink.Name
            }

        if ($null -eq $ActualLink) {

            $Failures += "$($ExpectedLink.Name): link missing"
            continue
        }

        if ([int]$ActualLink.Order -ne [int]$ExpectedLink.Order) {

            $Failures += `
                "$($ExpectedLink.Name): expected order $($ExpectedLink.Order), actual $($ActualLink.Order)"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-09" `
            -Domain "GPO Precedence" `
            -Status "PASS" `
            -Detail "Domain Controllers GPO precedence remains 1 DC Security Hardening, 2 Default Domain Controllers Policy, 3 Tier 0 restrictions, 4 service-account restrictions."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-09" `
            -Domain "GPO Precedence" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-09" `
        -Domain "GPO Precedence" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-10 — Domain Account Policy
# ===========================================================================

try {

    $Policy = Get-ADDefaultDomainPasswordPolicy `
        -Identity $DomainName `
        -ErrorAction Stop

    $Failures = @()

    if ($Policy.MinPasswordLength -ne 14) {
        $Failures += "Minimum password length is not 14"
    }

    if (-not $Policy.ComplexityEnabled) {
        $Failures += "Password complexity is disabled"
    }

    if ($Policy.PasswordHistoryCount -ne 24) {
        $Failures += "Password history is not 24"
    }

    if ($Policy.MaxPasswordAge.TotalDays -ne 90) {
        $Failures += "Maximum password age is not 90 days"
    }

    if ($Policy.MinPasswordAge.TotalDays -ne 1) {
        $Failures += "Minimum password age is not 1 day"
    }

    if ($Policy.ReversibleEncryptionEnabled) {
        $Failures += "Reversible encryption is enabled"
    }

    if ($Policy.LockoutThreshold -ne 5) {
        $Failures += "Lockout threshold is not 5"
    }

    if ($Policy.LockoutDuration.TotalMinutes -ne 30) {
        $Failures += "Lockout duration is not 30 minutes"
    }

    if ($Policy.LockoutObservationWindow.TotalMinutes -ne 30) {
        $Failures += "Lockout reset window is not 30 minutes"
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-10" `
            -Domain "Domain Account Policy" `
            -Status "PASS" `
            -Detail "Effective domain policy remains 14-character minimum, complexity enabled, history 24, maximum age 90 days, minimum age 1 day, lockout threshold 5, lockout duration/reset 30 minutes, and reversible encryption disabled."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-10" `
            -Domain "Domain Account Policy" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-10" `
        -Domain "Domain Account Policy" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-11 — LDAP Signing
# ===========================================================================

try {

    $LDAPValue = Get-ItemPropertyValue `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" `
        -Name "LDAPServerIntegrity" `
        -ErrorAction Stop

    if ([int]$LDAPValue -eq 2) {

        Add-ValidationResult `
            -ID "IAM-VAL-11" `
            -Domain "LDAP Signing" `
            -Status "PASS" `
            -Detail "Effective LDAPServerIntegrity is 2 (Require signing)."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-11" `
            -Domain "LDAP Signing" `
            -Status "FAIL" `
            -Detail "LDAPServerIntegrity is $LDAPValue; expected 2."
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-11" `
        -Domain "LDAP Signing" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# Effective User Rights — shared by IAM-VAL-12 and IAM-VAL-13
# ===========================================================================

$EffectiveUserRights = $null
$UserRightsError = $null

try {
    $EffectiveUserRights = Get-EffectiveUserRights
}
catch {
    $UserRightsError = $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-12 — Service Account Interactive Logon Restriction
# ===========================================================================

if ($null -eq $EffectiveUserRights) {

    Add-ValidationResult `
        -ID "IAM-VAL-12" `
        -Domain "Service Logon Restriction" `
        -Status "FAIL" `
        -Detail "Unable to read effective User Rights Assignment: $UserRightsError"
}
else {

    $LocalDeny = @(
        $EffectiveUserRights["SeDenyInteractiveLogonRight"]
    )

    $RemoteDeny = @(
        $EffectiveUserRights["SeDenyRemoteInteractiveLogonRight"]
    )

    $Failures = @()

    foreach ($ServiceAccount in $ServiceAccounts) {

        if ($ServiceAccount -notin $LocalDeny) {
            $Failures += "$ServiceAccount missing from local interactive deny"
        }

        if ($ServiceAccount -notin $RemoteDeny) {
            $Failures += "$ServiceAccount missing from RDP interactive deny"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-12" `
            -Domain "Service Logon Restriction" `
            -Status "PASS" `
            -Detail "All three service identities remain in both effective interactive-logon deny rights."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-12" `
            -Domain "Service Logon Restriction" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}

# ===========================================================================
# IAM-VAL-13 — Tier 0 Protection
# ===========================================================================

if ($null -eq $EffectiveUserRights) {

    Add-ValidationResult `
        -ID "IAM-VAL-13" `
        -Domain "Tier 0 Protection" `
        -Status "FAIL" `
        -Detail "Unable to read effective User Rights Assignment: $UserRightsError"
}
else {

    $ExpectedDenySet = @(
        "GG-T1-Server-Administrators",
        "GG-T2-Desktop-Support",
        "svc-sql-banking",
        "svc-sentinel-log",
        "svc-app-portal"
    )

    $LocalDeny = @(
        $EffectiveUserRights["SeDenyInteractiveLogonRight"]
    )

    $RemoteDeny = @(
        $EffectiveUserRights["SeDenyRemoteInteractiveLogonRight"]
    )

    $Failures = @()

    if (-not (
        Test-StringSetEqual `
            -Expected $ExpectedDenySet `
            -Actual $LocalDeny
    )) {
        $Failures += "Effective local-interactive deny set does not match approved five-principal set"
    }

    if (-not (
        Test-StringSetEqual `
            -Expected $ExpectedDenySet `
            -Actual $RemoteDeny
    )) {
        $Failures += "Effective RDP-interactive deny set does not match approved five-principal set"
    }

    if ("GG-T0-AD-Administrators" -in $LocalDeny) {
        $Failures += "Tier 0 group appears in local-interactive deny right"
    }

    if ("GG-T0-AD-Administrators" -in $RemoteDeny) {
        $Failures += "Tier 0 group appears in RDP-interactive deny right"
    }

    try {

        $Tier0Members = @(
            Get-ADGroupMember `
                -Identity "GG-T0-AD-Administrators" `
                -ErrorAction Stop |
            Select-Object -ExpandProperty SamAccountName
        )

        if ("adm.jc.olfato" -notin $Tier0Members) {
            $Failures += "adm.jc.olfato is not a member of GG-T0-AD-Administrators"
        }
    }
    catch {
        $Failures += "Unable to validate Tier 0 group membership"
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-13" `
            -Domain "Tier 0 Protection" `
            -Status "PASS" `
            -Detail "Effective deny rights contain the approved five-principal set while Tier 0 administration remains excluded and preserved."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-13" `
            -Domain "Tier 0 Protection" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}

# ===========================================================================
# IAM-VAL-14 — RDP Exposure
# ===========================================================================

try {

    $Failures = @()
    $Warnings = @()

    $RdpRegistry = Get-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -Name fDenyTSConnections `
        -ErrorAction Stop

    $RdpFirewallRules = @(
        Get-NetFirewallRule `
            -DisplayGroup "Remote Desktop" `
            -ErrorAction SilentlyContinue
    )

    $EnabledRdpFirewallRules = @(
        $RdpFirewallRules |
            Where-Object {
                $_.Enabled -eq "True" -or
                $_.Enabled -eq $true
            }
    )

    $RdpListeners = @(
        Get-NetTCPConnection `
            -LocalPort 3389 `
            -State Listen `
            -ErrorAction SilentlyContinue
    )

    if ($EnabledRdpFirewallRules.Count -gt 0) {

        $Failures += `
            "$($EnabledRdpFirewallRules.Count) Remote Desktop firewall rule(s) are enabled"
    }

    if (
        [int]$RdpRegistry.fDenyTSConnections -eq 0 -and
        $RdpListeners.Count -gt 0
    ) {

        $Warnings += `
            "RDP is enabled locally and TCP/3389 is listening; Remote Desktop firewall rules remain disabled"
    }

    if ($Failures.Count -gt 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-14" `
            -Domain "RDP Exposure" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
    elseif ($Warnings.Count -gt 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-14" `
            -Domain "RDP Exposure" `
            -Status "WARN" `
            -Detail (($Warnings -join "; ") + ". External reachability requires independent network validation.")
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-14" `
            -Domain "RDP Exposure" `
            -Status "PASS" `
            -Detail "No enabled Remote Desktop firewall exposure was detected and no locally active RDP listener requiring review was observed."
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-14" `
        -Domain "RDP Exposure" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-15 — Provisioning Integrity
# ===========================================================================

try {

    $Failures = @()

    if ($Employees.Count -ne 10) {
        $Failures += "CSV does not contain exactly 10 account definitions"
    }

    $UniqueUsernames = @(
        $Employees.Username |
            Sort-Object -Unique
    )

    if ($UniqueUsernames.Count -ne $Employees.Count) {
        $Failures += "Duplicate Username values exist in employees.csv"
    }

    $UniqueEmployeeIDs = @(
        $Employees.EmployeeID |
            Sort-Object -Unique
    )

    if ($UniqueEmployeeIDs.Count -ne $Employees.Count) {
        $Failures += "Duplicate EmployeeID values exist in employees.csv"
    }

    foreach ($Employee in $Employees) {

        if ($Employee.AccountType -notin @(
            "Privileged",
            "Standard",
            "Service"
        )) {
            $Failures += `
                "$($Employee.Username): unsupported AccountType $($Employee.AccountType)"
        }

        if ($Employee.PrimaryGroup -notin $ProjectGroupNames) {
            $Failures += `
                "$($Employee.Username): PrimaryGroup is outside the approved project RBAC set"
        }

        try {

            $Matches = @(
                Get-ADUser `
                    -Filter "SamAccountName -eq '$($Employee.Username)'" `
                    -ErrorAction Stop
            )

            if ($Matches.Count -ne 1) {
                $Failures += `
                    "$($Employee.Username): expected one deployed account, found $($Matches.Count)"
            }
        }
        catch {
            $Failures += `
                "$($Employee.Username): unable to validate unique deployed identity"
        }
    }

    if ($Failures.Count -eq 0) {

        Add-ValidationResult `
            -ID "IAM-VAL-15" `
            -Domain "Provisioning Integrity" `
            -Status "PASS" `
            -Detail "Declarative identity definitions are internally consistent and each controlled SamAccountName resolves to exactly one deployed identity."
    }
    else {

        Add-ValidationResult `
            -ID "IAM-VAL-15" `
            -Domain "Provisioning Integrity" `
            -Status "FAIL" `
            -Detail ($Failures -join "; ")
    }
}
catch {

    Add-ValidationResult `
        -ID "IAM-VAL-15" `
        -Domain "Provisioning Integrity" `
        -Status "FAIL" `
        -Detail $_.Exception.Message
}

# ===========================================================================
# IAM-VAL-16 — Overall Architecture Conformance
# ===========================================================================

$MandatoryResults = @(
    $ValidationResults |
        Where-Object {
            $_.ID -ne "IAM-VAL-16"
        }
)

$FailureCount = @(
    $MandatoryResults |
        Where-Object {
            $_.Status -eq "FAIL"
        }
).Count

$WarningCount = @(
    $MandatoryResults |
        Where-Object {
            $_.Status -eq "WARN"
        }
).Count

if ($FailureCount -gt 0) {

    Add-ValidationResult `
        -ID "IAM-VAL-16" `
        -Domain "Architecture Conformance" `
        -Status "FAIL" `
        -Detail "$FailureCount mandatory assurance check(s) failed."
}
elseif ($WarningCount -gt 0) {

    Add-ValidationResult `
        -ID "IAM-VAL-16" `
        -Domain "Architecture Conformance" `
        -Status "WARN" `
        -Detail "No mandatory assurance checks failed, but $WarningCount warning(s) require review."
}
else {

    Add-ValidationResult `
        -ID "IAM-VAL-16" `
        -Domain "Architecture Conformance" `
        -Status "PASS" `
        -Detail "All mandatory IAM assurance checks passed with no detected configuration drift."
}

# ---------------------------------------------------------------------------
# Output Selection
# ---------------------------------------------------------------------------

$ArchitectureIDs = @(
    "IAM-VAL-01",
    "IAM-VAL-02",
    "IAM-VAL-03",
    "IAM-VAL-04",
    "IAM-VAL-05",
    "IAM-VAL-06",
    "IAM-VAL-07",
    "IAM-VAL-15"
)

$SecurityIDs = @(
    "IAM-VAL-08",
    "IAM-VAL-09",
    "IAM-VAL-10",
    "IAM-VAL-11",
    "IAM-VAL-12",
    "IAM-VAL-13",
    "IAM-VAL-14"
)

switch ($View) {

    "Architecture" {

        $DisplayResults = @(
            $ValidationResults |
                Where-Object {
                    $_.ID -in $ArchitectureIDs
                }
        )
    }

    "Security" {

        $DisplayResults = @(
            $ValidationResults |
                Where-Object {
                    $_.ID -in $SecurityIDs
                }
        )
    }

    "Summary" {

        $DisplayResults = @(
            $ValidationResults |
                Select-Object ID, Domain, Status
        )
    }

    default {

        $DisplayResults = @(
            $ValidationResults
        )
    }
}

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Validation Results"
Write-Host "--------------------------------------------------------------"

$DisplayResults |
    Format-Table `
        ID,
        Domain,
        Status,
        Detail `
        -AutoSize `
        -Wrap

$Passed = @(
    $ValidationResults |
        Where-Object {
            $_.Status -eq "PASS"
        }
).Count

$Failed = @(
    $ValidationResults |
        Where-Object {
            $_.Status -eq "FAIL"
        }
).Count

$Warnings = @(
    $ValidationResults |
        Where-Object {
            $_.Status -eq "WARN"
        }
).Count

$OverallResult = (
    $ValidationResults |
        Where-Object {
            $_.ID -eq "IAM-VAL-16"
        }
).Status

Write-Host ""
Write-Host "Validation Summary"
Write-Host "--------------------------------------------------------------"
Write-Host "Checks Passed : $Passed"
Write-Host "Checks Failed : $Failed"
Write-Host "Warnings      : $Warnings"
Write-Host "Result        : $OverallResult"
Write-Host ""

if ($OverallResult -eq "PASS") {
    exit 0
}

exit 1