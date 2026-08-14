<#
.SYNOPSIS
    Deploys the enterprise Organizational Unit (OU) structure
    for the Banking Active Directory environment.

.AUTHOR
    Jon Carlo Yuzon Olfato

.REPOSITORY
    enterprise-banking-iam-architecture

.NOTES
    Domain:
        banking.lab

    Distinguished Name:
        DC=banking,DC=lab
#>

#------------------------------------------------------------
# Strict Mode
#------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

#------------------------------------------------------------
# Variables
#------------------------------------------------------------

$DomainDN = "DC=banking,DC=lab"

$OrganizationalUnits = @(

    @{
        Name   = "Tier0_Identity_Infrastructure"
        Parent = $DomainDN
    },

    @{
        Name   = "Domain_Controllers"
        Parent = "OU=Tier0_Identity_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Privileged_Accounts"
        Parent = "OU=Tier0_Identity_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Administrative_Groups"
        Parent = "OU=Tier0_Identity_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Tier1_Server_Infrastructure"
        Parent = $DomainDN
    },

    @{
        Name   = "Infrastructure_Servers"
        Parent = "OU=Tier1_Server_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Application_Servers"
        Parent = "OU=Tier1_Server_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Server_Admins"
        Parent = "OU=Tier1_Server_Infrastructure,$DomainDN"
    },

    @{
        Name   = "Tier2_User_Computing"
        Parent = $DomainDN
    },

    @{
        Name   = "Workstations"
        Parent = "OU=Tier2_User_Computing,$DomainDN"
    },

    @{
        Name   = "Corporate_Users"
        Parent = "OU=Tier2_User_Computing,$DomainDN"
    },

    @{
        Name   = "Department_Groups"
        Parent = "OU=Tier2_User_Computing,$DomainDN"
    },

    @{
        Name   = "Desktop_Support"
        Parent = "OU=Tier2_User_Computing,$DomainDN"
    },

    @{
        Name   = "Service_Accounts"
        Parent = $DomainDN
    }

)

#------------------------------------------------------------
# Function
#------------------------------------------------------------

function New-BankingOU {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Parent

    )

    try {

        $DistinguishedName = "OU=$Name,$Parent"

        $ExistingOU = Get-ADOrganizationalUnit `
            -LDAPFilter "(distinguishedName=$DistinguishedName)" `
            -ErrorAction SilentlyContinue

        if ($null -ne $ExistingOU) {

            Write-Host "[SKIP] OU already exists: $Name"

            return

        }

        New-ADOrganizationalUnit `
            -Name $Name `
            -Path $Parent `
            -ProtectedFromAccidentalDeletion $true

        Write-Host "[CREATE] OU created: $Name"

    }

    catch {

        Write-Host "[ERROR] Failed to create OU: $Name"
        Write-Host $_.Exception.Message

        throw

    }

}

#------------------------------------------------------------
# Main
#------------------------------------------------------------

Write-Host ""
Write-Host "========================================================="
Write-Host " Enterprise Banking IAM Architecture"
Write-Host " Organizational Unit Deployment"
Write-Host "========================================================="
Write-Host ""

foreach ($OU in $OrganizationalUnits) {

    New-BankingOU `
        -Name $OU.Name `
        -Parent $OU.Parent

}

Write-Host ""
Write-Host "========================================================="
Write-Host " OU deployment completed successfully."
Write-Host "========================================================="
Write-Host ""