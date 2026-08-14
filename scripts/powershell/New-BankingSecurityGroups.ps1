<#
.SYNOPSIS
    Provisions the Enterprise Banking IAM security group architecture.

.DESCRIPTION
    Creates the defined Global Security Groups for the Tier 0, Tier 1,
    Tier 2 and departmental RBAC model.

    The script is idempotent:
    - Existing groups are detected and skipped.
    - Missing groups are created.
    - Existing groups are not duplicated.

    All groups are created with Security scope and placed into their
    designated organisational units.

.TARGET ENVIRONMENT
    Domain: banking.lab
    Domain Controller: AU-SYD-DC01
    Base DN: DC=banking,DC=lab
#>

Import-Module ActiveDirectory -ErrorAction Stop

$DomainDN = "DC=banking,DC=lab"

# ---------------------------------------------------------------------------
# Security Group Definitions
# ---------------------------------------------------------------------------

$SecurityGroups = @(
    @{
        Name        = "GG-T0-AD-Administrators"
        Description = "Tier 0 security group for Active Directory administration."
        OU          = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T0-Domain-Controllers"
        Description = "Tier 0 security group for Domain Controller administration."
        OU          = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T0-Identity-Operations"
        Description = "Tier 0 security group for identity infrastructure operations."
        OU          = "OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T1-Server-Administrators"
        Description = "Tier 1 security group for general server administration."
        OU          = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T1-Infrastructure-Administrators"
        Description = "Tier 1 security group for infrastructure server administration."
        OU          = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T1-Application-Administrators"
        Description = "Tier 1 security group for application server administration."
        OU          = "OU=Server_Admins,OU=Tier1_Server_Infrastructure,$DomainDN"
    },
    @{
        Name        = "GG-T2-Desktop-Support"
        Description = "Tier 2 security group for workstation and desktop support operations."
        OU          = "OU=Desktop_Support,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name        = "GG-Department-Finance"
        Description = "Department security group for Finance users."
        OU          = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name        = "GG-Department-HR"
        Description = "Department security group for Human Resources users."
        OU          = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name        = "GG-Department-IT"
        Description = "Department security group for Information Technology users."
        OU          = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    },
    @{
        Name        = "GG-Department-Operations"
        Description = "Department security group for Operations users."
        OU          = "OU=Department_Groups,OU=Tier2_User_Computing,$DomainDN"
    }
)

# ---------------------------------------------------------------------------
# Helper Function — Verify Target OU
# ---------------------------------------------------------------------------

function Test-TargetOU {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DistinguishedName
    )

    try {
        Get-ADOrganizationalUnit `
            -Identity $DistinguishedName `
            -ErrorAction Stop | Out-Null

        return $true
    }
    catch {
        Write-Host "[ERROR] Target OU does not exist: $DistinguishedName"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Helper Function — Find Existing Group in Target OU
# ---------------------------------------------------------------------------

function Get-ExistingSecurityGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $true)]
        [string]$TargetOU
    )

    try {
        $Group = Get-ADGroup `
            -Filter "Name -eq '$GroupName'" `
            -SearchBase $TargetOU `
            -SearchScope OneLevel `
            -ErrorAction Stop

        return $Group
    }
    catch {
        return $null
    }
}

# ---------------------------------------------------------------------------
# Provision Security Groups
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================================="
Write-Host " Enterprise Banking IAM Architecture"
Write-Host " Security Group / RBAC Deployment"
Write-Host "========================================================="
Write-Host ""

foreach ($Group in $SecurityGroups) {

    try {

        # Verify target OU exists
        if (-not (Test-TargetOU -DistinguishedName $Group.OU)) {
            throw "Target OU does not exist: $($Group.OU)"
        }

        # Check whether the group already exists inside the target OU
        $ExistingGroup = Get-ExistingSecurityGroup `
            -GroupName $Group.Name `
            -TargetOU $Group.OU

        if ($ExistingGroup) {

            Write-Host "[SKIP] Security group already exists: $($Group.Name)"
            Write-Host "       DN: $($ExistingGroup.DistinguishedName)"
            continue
        }

        # Create the security group
        New-ADGroup `
            -Name $Group.Name `
            -SamAccountName $Group.Name `
            -GroupCategory Security `
            -GroupScope Global `
            -Path $Group.OU `
            -Description $Group.Description `
            -ErrorAction Stop

        Write-Host "[CREATE] Security group created: $($Group.Name)"
        Write-Host "         Scope: Global"
        Write-Host "         Type: Security"
        Write-Host "         OU: $($Group.OU)"
    }
    catch {

        Write-Host "[ERROR] Failed to provision security group: $($Group.Name)"
        Write-Host "        $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Deployment Completion
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================================="
Write-Host " Security group deployment completed."
Write-Host "========================================================="
Write-Host ""

# ---------------------------------------------------------------------------
# Programmatic Validation
# ---------------------------------------------------------------------------

Write-Host "RBAC Security Group Validation"
Write-Host "---------------------------------------------------------"

$ValidationFailures = 0

foreach ($Group in $SecurityGroups) {

    try {

        $ValidationGroup = Get-ADGroup `
            -Filter "Name -eq '$($Group.Name)'" `
            -SearchBase $Group.OU `
            -SearchScope OneLevel `
            -Properties GroupScope, GroupCategory, DistinguishedName `
            -ErrorAction Stop

        if ($ValidationGroup.GroupScope -eq "Global" -and
            $ValidationGroup.GroupCategory -eq "Security") {

            Write-Host "[VALID] $($ValidationGroup.Name)"
            Write-Host "        Scope: $($ValidationGroup.GroupScope)"
            Write-Host "        Category: $($ValidationGroup.GroupCategory)"
            Write-Host "        DN: $($ValidationGroup.DistinguishedName)"
        }
        else {

            Write-Host "[INVALID] Security group configuration: $($Group.Name)"
            $ValidationFailures++
        }
    }
    catch {

        Write-Host "[INVALID] Security group not found: $($Group.Name)"
        $ValidationFailures++
    }
}

Write-Host ""

if ($ValidationFailures -eq 0) {

    Write-Host "========================================================="
    Write-Host " RBAC validation completed successfully."
    Write-Host "========================================================="
}
else {

    Write-Host "========================================================="
    Write-Host " RBAC validation completed with $ValidationFailures failure(s)."
    Write-Host "========================================================="
}