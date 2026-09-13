# Enterprise Banking IAM — User Account Model

## Purpose

This document defines the identity and account model implemented within the Enterprise Banking IAM Architecture.

The model establishes a controlled Active Directory identity structure for privileged, standard and service accounts. Account placement, naming, RBAC assignment and security attributes are defined according to administrative tier and operational function.

The design is intended to demonstrate enterprise identity governance principles applicable to a banking environment, including least privilege, administrative separation, role-based access control and controlled service-account management.

## Target Environment

| Component | Value |
| --- | --- |
| Domain Controller | AU-SYD-DC01 |
| Operating System | Windows Server 2022 |
| Domain | banking.lab |
| Forest Root | banking.lab |
| Base Distinguished Name | DC=banking,DC=lab |
| Directory Service | Active Directory Domain Services |
| Provisioning Method | PowerShell / Active Directory module |
| Account Definition Source | employees.csv |
| Provisioning Script | Import-BankingUsers.ps1 |

## Identity Population

The IAM model uses a controlled 10-identity footprint consisting of:

| Account Type | Count | Purpose |
| --- | ---: | --- |
| Privileged | 3 | Tiered administrative identities |
| Standard | 4 | Corporate workforce identities |
| Service | 3 | Non-human application and infrastructure identities |
| **Total** | **10** | **Controlled IAM test population** |

The identity population is intentionally limited to a defined test dataset so that account provisioning, RBAC assignment and validation can be independently verified.

## Account Classification

### Standard Accounts

Standard accounts represent normal workforce identities used for business operations.

The model contains four standard identities:

| Employee ID | Account | Department | Target OU | RBAC Group |
| --- | --- | --- | --- | --- |
| EMP004 | `emily.taylor` | Finance | `OU=Corporate_Users,OU=Tier2_User_Computing` | `GG-Department-Finance` |
| EMP005 | `james.anderson` | Human Resources | `OU=Corporate_Users,OU=Tier2_User_Computing` | `GG-Department-HR` |
| EMP006 | `olivia.thomas` | Operations | `OU=Corporate_Users,OU=Tier2_User_Computing` | `GG-Department-Operations` |
| EMP007 | `daniel.moore` | Information Technology | `OU=Corporate_Users,OU=Tier2_User_Computing` | `GG-Department-IT` |

Standard accounts are configured to require password change at first logon.

They are not configured with `PasswordNeverExpires` or `CannotChangePassword`.

### Privileged Accounts

Privileged accounts are dedicated administrative identities used to perform elevated administrative functions.

Privileged identities are separated from standard workforce identities and assigned to administrative OUs according to their administrative tier.

The model contains three privileged identities:

| Employee ID | Account | Administrative Tier | Target OU | RBAC Group |
| --- | --- | --- | --- | --- |
| EMP001 | `adm.jc.olfato` | Tier 0 | `OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure` | `GG-T0-AD-Administrators` |
| EMP002 | `adm.syd.srv01` | Tier 1 | `OU=Server_Admins,OU=Tier1_Server_Infrastructure` | `GG-T1-Server-Administrators` |
| EMP003 | `adm.syd.help01` | Tier 2 | `OU=Desktop_Support,OU=Tier2_User_Computing` | `GG-T2-Desktop-Support` |

Privileged accounts are configured with `AccountNotDelegated = True` to reduce exposure to credential delegation attacks.

Privileged accounts are not configured with `PasswordNeverExpires`.

### Service Accounts

Service accounts represent non-human identities used by infrastructure, monitoring and application services.

The model contains three service identities:

| Employee ID | Account | Purpose | Target OU | RBAC Group |
| --- | --- | --- | --- | --- |
| SVC001 | `svc-sql-banking` | Banking SQL service | `OU=Service_Accounts` | `GG-Department-IT` |
| SVC002 | `svc-sentinel-log` | Security monitoring/logging service | `OU=Service_Accounts` | `GG-Department-IT` |
| SVC003 | `svc-app-portal` | Banking application portal service | `OU=Service_Accounts` | `GG-Department-IT` |

Service accounts are separated from human identities through a dedicated `Service_Accounts` OU.

The following controls are applied during provisioning:

- `PasswordNeverExpires = True`
- `CannotChangePassword = True`
- `AccountNotDelegated = True`
- Accidental deletion protection enabled

Interactive logon restrictions are intentionally deferred to the Group Policy implementation stage.

## Naming Convention

The account naming convention distinguishes administrative and service identities from standard workforce accounts.

### Standard Account Population

Standard accounts use a lowercase:

```text
firstname.surname
```

Example: `emily.taylor`

### Privileged Account Population

Privileged accounts use the:

```text
adm.<identifier>
```

pattern.

Examples: `adm.jc.olfato`, `adm.syd.srv01`, `adm.syd.help01`

The `adm.` prefix identifies an administrative identity and separates it from the associated user's standard identity.

### Service Account Population

Service accounts use the:

```text
svc-<service>-<function>
```

pattern.

Examples: `svc-sql-banking`, `svc-sentinel-log`, `svc-app-portal`

The `svc-` prefix clearly identifies non-human identities.

## Display Name Convention

The Active Directory `SamAccountName` is treated as the stable account identifier.

Human-readable attributes such as `GivenName`, `Surname`, `DisplayName` and the Active Directory object common name may be maintained independently to support organisational naming standards.

For example:

| Attribute | Value |
| --- | --- |
| SamAccountName | `adm.jc.olfato` |
| GivenName | `JC` |
| Surname | `Olfato` |
| DisplayName | `JC Olfato` |

Changing the display attributes does not change the account's SAM identifier or RBAC assignment.

## User Principal Name

User Principal Names follow the Active Directory domain namespace:

```text
<SamAccountName>@banking.lab
```

Examples: `adm.jc.olfato@banking.lab`, `emily.taylor@banking.lab`, `svc-sql-banking@banking.lab`

The UPN provides a consistent authentication identifier while preserving the underlying account naming convention.

## OU Placement Model

Account placement follows the administrative and operational boundaries established during the OU architecture stage.

| Account Population | Target OU |
| --- | --- |
| Tier 0 privileged identities | `Privileged_Accounts` under `Tier0_Identity_Infrastructure` |
| Tier 1 privileged identities | `Server_Admins` under `Tier1_Server_Infrastructure` |
| Tier 2 privileged identities | `Desktop_Support` under `Tier2_User_Computing` |
| Standard workforce identities | `Corporate_Users` under `Tier2_User_Computing` |
| Service identities | `Service_Accounts` |

OU placement provides the structural foundation for applying differentiated Group Policy and administrative controls.

## RBAC Assignment Model

Each identity receives a designated project RBAC Global Security Group based on its role.

The account-to-group relationship is intentionally explicit:

```text
Identity
   |
   +-- Account Type
   |
   +-- Administrative / Business Role
   |
   +-- Target OU
   |
   +-- Designated RBAC Group
```

### Privileged RBAC

| Account | RBAC Group |
| --- | --- |
| `adm.jc.olfato` | `GG-T0-AD-Administrators` |
| `adm.syd.srv01` | `GG-T1-Server-Administrators` |
| `adm.syd.help01` | `GG-T2-Desktop-Support` |

### Standard RBAC

| Account | RBAC Group |
| --- | --- |
| `emily.taylor` | `GG-Department-Finance` |
| `james.anderson` | `GG-Department-HR` |
| `olivia.thomas` | `GG-Department-Operations` |
| `daniel.moore` | `GG-Department-IT` |

### Service RBAC

| Account | RBAC Group |
| --- | --- |
| `svc-sql-banking` | `GG-Department-IT` |
| `svc-sentinel-log` | `GG-Department-IT` |
| `svc-app-portal` | `GG-Department-IT` |

The designated RBAC group represents the project-defined role assignment for each controlled identity. It does not modify or represent the native Active Directory `primaryGroupID` attribute.

RBAC membership is validated independently after provisioning.

## Account Security Controls

The provisioning model applies differentiated security attributes based on account type.

| Control | Privileged | Standard | Service |
| --- | --- | --- | --- |
| Enabled | Yes | Yes | Yes |
| Password Never Expires | No | No | Yes |
| Cannot Change Password | No | No | Yes |
| Change Password at Next Logon | No | Yes | No |
| Account Not Delegated | Yes | No | Yes |
| Accidental Deletion Protection | Yes | Yes | Yes |
| Dedicated OU Placement | Yes | Yes | Yes |
| Designated RBAC Group | Yes | Yes | Yes |
| Interactive Logon Restriction | GPO stage | N/A | GPO stage |

The controls are applied according to the intended account function rather than uniformly across all identities.

## Password Management

Initial passwords are generated programmatically by the provisioning script.

The provisioning process:

1. Generates a random initial password.
2. Constructs a `SecureString`.
3. Assigns the password during account creation.
4. Does not write the password to the PowerShell console.
5. Applies account-type-specific password controls.

Initial passwords are deliberately excluded from provisioning logs and repository documentation.

Service-account passwords are configured not to expire as part of this laboratory implementation. Additional credential-management controls may be introduced in a production environment through managed service accounts, privileged access management or dedicated secrets-management platforms.

## Account Protection

All provisioned accounts are configured with Active Directory accidental-deletion protection.

This control is validated independently using the ProtectedFromAccidentalDeletion attribute.

Privileged and service identities additionally use:

```text
AccountNotDelegated = True
```

to provide an additional control against inappropriate Kerberos delegation scenarios.

## Provisioning Source of Truth

The account population is defined in:

```text
scripts/powershell/employees.csv
```

The CSV provides the declarative account definition consumed by:

```text
scripts/powershell/Import-BankingUsers.ps1
```

The provisioning process therefore separates:

```text
Account Definition
       ↓
      CSV
       ↓
Provisioning Logic
       ↓
Active Directory
```

This approach allows the account population to be reviewed independently from the PowerShell implementation.

## Idempotent Provisioning

The provisioning script is designed to be safely re-executed.

Existing accounts are detected by `SamAccountName` and skipped rather than recreated.

Expected behaviour:

```text
Account does not exist
        ↓
      CREATE

Account already exists
        ↓
      SKIP
```

The provisioning implementation was executed a second time after initial provisioning and returned `[SKIP]` results for all 10 existing identities.

The resulting validation completed with:

```text
Validation failures: 0
```

This demonstrates repeatable provisioning without duplicate account creation.

## Validation Requirements

The completed account model is validated against Active Directory using multiple independent checks.

Validation includes:

- Account existence
- Account count
- SAM account naming
- Enabled state
- Distinguished Name / OU placement
- Display attributes
- RBAC group membership
- Password policy attributes
- `AccountNotDelegated`
- `ProtectedFromAccidentalDeletion`
- Idempotent re-execution

The validation process is documented separately in:

```text
evidence/user-provisioning-log.md
```

## Scope and Control Boundaries

This account model focuses on identity provisioning and foundational account-level security controls.

Controls implemented outside the provisioning workflow are documented separately.

These include:

- domain account policy;
- LDAP signing;
- service-account interactive-logon restrictions;
- Tier 0 administrative logon restrictions; and
- Group Policy enforcement.

These controls are implemented through Group Policy and documented in:

`../documentation/gpo-security-controls.md`

Security monitoring, advanced workstation hardening, privileged administrative workstation controls, credential rotation automation and broader authentication hardening remain outside the scope of this account-provisioning model.

## Security Design Principles

The account model is based on the following principles:

### Least Privilege

Identities receive only the primary RBAC assignment required for their defined function.

### Administrative Separation

Privileged identities are separated into Tier 0, Tier 1 and Tier 2 administrative boundaries.

### Identity Separation

Administrative identities are separated from standard workforce identities.

### Service Identity Isolation

Non-human identities are placed in a dedicated service-account OU and receive differentiated security controls.

### Role-Based Access Control

Access assignments are represented through Global Security Groups rather than direct user-to-resource permissions.

### Defence in Depth

Account protection, delegation controls, password controls, OU separation and RBAC are applied as complementary controls.

### Repeatable Provisioning

Identity creation is automated through a declarative CSV source and an idempotent PowerShell provisioning process.

## Implementation Status

| Capability | Status |
| --- | --- |
| 10-identity population defined | Complete |
| Privileged identity provisioning | Complete |
| Standard identity provisioning | Complete |
| Service identity provisioning | Complete |
| OU-based account placement | Complete |
| RBAC group assignment | Complete |
| Account security controls | Complete |
| Accidental deletion protection | Complete |
| Idempotency validation | Complete |
| Independent AD validation | Complete |
| Identity attribute standardisation | Complete |
| Service-account interactive logon restriction | Complete through GPO |
