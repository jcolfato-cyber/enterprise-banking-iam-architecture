# Enterprise Banking IAM — RBAC Security Group Provisioning Log

## Provisioning Script

`New-BankingSecurityGroups.ps1`

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

Programmatically provision the Global Security Groups supporting the Enterprise Banking IAM Role-Based Access Control (RBAC) model.

The security group architecture separates administrative responsibilities across Tier 0, Tier 1 and Tier 2 security boundaries while providing department-based access control groups.

## Security Group Model

The provisioning script creates 11 Global Security Groups:

### Tier 0 — Identity Infrastructure

- `GG-T0-AD-Administrators`
- `GG-T0-Domain-Controllers`
- `GG-T0-Identity-Operations`

### Tier 1 — Server Infrastructure

- `GG-T1-Server-Administrators`
- `GG-T1-Infrastructure-Administrators`
- `GG-T1-Application-Administrators`

### Tier 2 — User Computing

- `GG-T2-Desktop-Support`

### Departmental Access Groups

- `GG-Department-Finance`
- `GG-Department-HR`
- `GG-Department-IT`
- `GG-Department-Operations`

All groups were provisioned as Global Security Groups.

---

## Initial Provisioning Execution

The `New-BankingSecurityGroups.ps1` script was executed from an elevated PowerShell session on AU-SYD-DC01.

The initial execution successfully created all 11 security groups.

### Provisioning Output

```powershell
=========================================================
 Enterprise Banking IAM Architecture
 Security Group / RBAC Deployment
=========================================================

[CREATE] Security group created: GG-T0-AD-Administrators
         Scope: Global
         Type: Security
         OU: OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T0-Domain-Controllers
         Scope: Global
         Type: Security
         OU: OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T0-Identity-Operations
         Scope: Global
         Type: Security
         OU: OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T1-Server-Administrators
         Scope: Global
         Type: Security
         OU: OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T1-Infrastructure-Administrators
         Scope: Global
         Type: Security
         OU: OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T1-Application-Administrators
         Scope: Global
         Type: Security
         OU: OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[CREATE] Security group created: GG-T2-Desktop-Support
         Scope: Global
         Type: Security
         OU: OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
[CREATE] Security group created: GG-Department-Finance
         Scope: Global
         Type: Security
         OU: OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[CREATE] Security group created: GG-Department-HR
         Scope: Global
         Type: Security
         OU: OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[CREATE] Security group created: GG-Department-IT
         Scope: Global
         Type: Security
         OU: OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[CREATE] Security group created: GG-Department-Operations
         Scope: Global
         Type: Security
         OU: OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab

=========================================================
 Security group deployment completed.
=========================================================

RBAC Security Group Validation
---------------------------------------------------------
[VALID] GG-T0-AD-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T0-AD-Administrators,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T0-Domain-Controllers
        Scope: Global
        Category: Security
        DN: CN=GG-T0-Domain-Controllers,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T0-Identity-Operations
        Scope: Global
        Category: Security
        DN: CN=GG-T0-Identity-Operations,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Server-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Server-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Infrastructure-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Infrastructure-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Application-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Application-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T2-Desktop-Support
        Scope: Global
        Category: Security
        DN: CN=GG-T2-Desktop-Support,OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-Finance
        Scope: Global
        Category: Security
        DN: CN=GG-Department-Finance,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-HR
        Scope: Global
        Category: Security
        DN: CN=GG-Department-HR,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-IT
        Scope: Global
        Category: Security
        DN: CN=GG-Department-IT,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-Operations
        Scope: Global
        Category: Security
        DN: CN=GG-Department-Operations,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab

=========================================================
 RBAC validation completed successfully.
=========================================================
```

## Idempotency Validation

The provisioning script was executed a second time after the initial deployment.
Existing security groups were detected and skipped rather than recreated.

### Idempotency Output

```powershell
=========================================================
 Enterprise Banking IAM Architecture
 Security Group / RBAC Deployment
=========================================================

[SKIP] Security group already exists: GG-T0-AD-Administrators
       DN: CN=GG-T0-AD-Administrators,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T0-Domain-Controllers
       DN: CN=GG-T0-Domain-Controllers,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T0-Identity-Operations
       DN: CN=GG-T0-Identity-Operations,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T1-Server-Administrators
       DN: CN=GG-T1-Server-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T1-Infrastructure-Administrators
       DN: CN=GG-T1-Infrastructure-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T1-Application-Administrators
       DN: CN=GG-T1-Application-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[SKIP] Security group already exists: GG-T2-Desktop-Support
       DN: CN=GG-T2-Desktop-Support,OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
[SKIP] Security group already exists: GG-Department-Finance
       DN: CN=GG-Department-Finance,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[SKIP] Security group already exists: GG-Department-HR
       DN: CN=GG-Department-HR,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[SKIP] Security group already exists: GG-Department-IT
       DN: CN=GG-Department-IT,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[SKIP] Security group already exists: GG-Department-Operations
       DN: CN=GG-Department-Operations,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab

=========================================================
 Security group deployment completed.
=========================================================

RBAC Security Group Validation
---------------------------------------------------------
[VALID] GG-T0-AD-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T0-AD-Administrators,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T0-Domain-Controllers
        Scope: Global
        Category: Security
        DN: CN=GG-T0-Domain-Controllers,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T0-Identity-Operations
        Scope: Global
        Category: Security
        DN: CN=GG-T0-Identity-Operations,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Server-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Server-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Infrastructure-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Infrastructure-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T1-Application-Administrators
        Scope: Global
        Category: Security
        DN: CN=GG-T1-Application-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
[VALID] GG-T2-Desktop-Support
        Scope: Global
        Category: Security
        DN: CN=GG-T2-Desktop-Support,OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-Finance
        Scope: Global
        Category: Security
        DN: CN=GG-Department-Finance,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-HR
        Scope: Global
        Category: Security
        DN: CN=GG-Department-HR,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-IT
        Scope: Global
        Category: Security
        DN: CN=GG-Department-IT,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
[VALID] GG-Department-Operations
        Scope: Global
        Category: Security
        DN: CN=GG-Department-Operations,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab

=========================================================
 RBAC validation completed successfully.
=========================================================
```

The idempotency test confirms that the provisioning script can be safely re-executed without creating duplicate security groups.

## Active Directory Validation

The resulting security group architecture was independently validated against Active Directory using:

```powershell
Get-ADGroup -Filter * |
    Where-Object {$_.Name -like "GG-*"} |
    Select-Object Name, GroupScope, GroupCategory, DistinguishedName |
    Sort-Object Name
```

### Validation Output

```powershell
Name                                GroupScope GroupCategory DistinguishedName
----                                ---------- ------------- -----------------
GG-Department-Finance                   Global      Security CN=GG-Department-Finance,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
GG-Department-HR                        Global      Security CN=GG-Department-HR,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
GG-Department-IT                        Global      Security CN=GG-Department-IT,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
GG-Department-Operations                Global      Security CN=GG-Department-Operations,OU=Department_Groups,OU=Tier2_User_Computing,DC=banking,DC=lab
GG-T0-AD-Administrators                 Global      Security CN=GG-T0-AD-Administrators,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
GG-T0-Domain-Controllers                Global      Security CN=GG-T0-Domain-Controllers,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
GG-T0-Identity-Operations               Global      Security CN=GG-T0-Identity-Operations,OU=Administrative_Groups,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
GG-T1-Application-Administrators        Global      Security CN=GG-T1-Application-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
GG-T1-Infrastructure-Administrators     Global      Security CN=GG-T1-Infrastructure-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
GG-T1-Server-Administrators             Global      Security CN=GG-T1-Server-Administrators,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab
GG-T2-Desktop-Support                   Global      Security CN=GG-T2-Desktop-Support,OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
```

## Security Group Count Validation

```powershell
Get-ADGroup -Filter * |
    Where-Object {$_.Name -like "GG-*"} |
    Measure-Object
```

### Count Output

```powershell
Count    : 11
```

The expected security group count is 11. The Active Directory validation returned a count of 11.
