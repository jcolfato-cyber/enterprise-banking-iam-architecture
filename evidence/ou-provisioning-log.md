# Enterprise Banking IAM — Organisational Unit Provisioning Log

## Provisioning Script

`New-BankingOU.ps1`

## Target Environment

| Component | Value |
| --- | --- |
| Domain Controller | AU-SYD-DC01 |
| Domain | banking.lab |
| Forest Root | banking.lab |
| Base Distinguished Name | DC=banking,DC=lab |
| Platform | Windows Server 2022 |
| Provisioning Method | PowerShell / Active Directory module |

## Objective

Programmatically provision the enterprise Active Directory organisational unit hierarchy supporting the Tier 0, Tier 1 and Tier 2 administrative model.

## Initial Provisioning Execution

The `New-BankingOU.ps1` script was executed from an elevated PowerShell session on AU-SYD-DC01.

The initial execution successfully created the required organisational units.

### Provisioning Output

```powershell
=========================================================
 Enterprise Banking IAM Architecture
 Organizational Unit Deployment
=========================================================

[CREATE] OU created: Tier0_Identity_Infrastructure
[CREATE] OU created: Domain_Controllers
[CREATE] OU created: Privileged_Accounts
[CREATE] OU created: Administrative_Groups
[CREATE] OU created: Tier1_Server_Infrastructure
[CREATE] OU created: Infrastructure_Servers
[CREATE] OU created: Application_Servers
[CREATE] OU created: Server_Admins
[CREATE] OU created: Tier2_User_Computing
[CREATE] OU created: Workstations
[CREATE] OU created: Corporate_Users
[CREATE] OU created: Department_Groups
[CREATE] OU created: Desktop_Support
[CREATE] OU created: Service_Accounts

=========================================================
 OU deployment completed successfully.
=========================================================
```

## Idempotency Validation

The provisioning script was executed a second time from an elevated PowerShell session.
Existing organisational units were detected and skipped rather than recreated.

### Idempotency Output

```powershell
=========================================================
 Enterprise Banking IAM Architecture
 Organizational Unit Deployment
=========================================================

[SKIP] OU already exists: Tier0_Identity_Infrastructure
[SKIP] OU already exists: Domain_Controllers
[SKIP] OU already exists: Privileged_Accounts
[SKIP] OU already exists: Administrative_Groups
[SKIP] OU already exists: Tier1_Server_Infrastructure
[SKIP] OU already exists: Infrastructure_Servers
[SKIP] OU already exists: Application_Servers
[SKIP] OU already exists: Server_Admins
[SKIP] OU already exists: Tier2_User_Computing
[SKIP] OU already exists: Workstations
[SKIP] OU already exists: Corporate_Users
[SKIP] OU already exists: Department_Groups
[SKIP] OU already exists: Desktop_Support
[SKIP] OU already exists: Service_Accounts

=========================================================
 OU deployment completed successfully.
=========================================================
```

## Active Directory Validation

The resulting OU structure was validated directly against Active Directory using:

```powershell
Get-ADOrganizationalUnit -Filter * |
    Select-Object Name, DistinguishedName |
    Sort-Object DistinguishedName
```

### Output

```powershell
Name                          DistinguishedName
----                          -----------------
Administrative_Groups         OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
Application_Servers           OU=Application_Servers,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
Corporate_Users               OU=Corporate_Users,OU=Tier2_User_Computing,DC=banking,DC=lab
Department_Groups             OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
Desktop_Support               OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
Domain Controllers            OU=Domain Controllers,DC=banking,DC=lab
Domain_Controllers            OU=Domain_Controllers,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
Infrastructure_Servers        OU=Infrastructure_Servers,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
Privileged_Accounts           OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
Server_Admins                 OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
Service_Accounts              OU=Service_Accounts,DC=banking,DC=lab
Tier0_Identity_Infrastructure OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
Tier1_Server_Infrastructure   OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
Tier2_User_Computing          OU=Tier2_User_Computing,DC=banking,DC=lab
Workstations                  OU=Workstations,OU=Tier2_User_Computing,DC=banking,DC=lab
```

The validation confirmed that the expected custom organisational units exist within the banking.lab domain.

## OU Count Validation

```powershell
Get-ADOrganizationalUnit -Filter * |
    Measure-Object
```

### Count Output

```powershell
Count    : 15
```

The total of 15 organisational units includes the 13 custom organisational units provisioned for this project and the existing default Active Directory organisational units.
