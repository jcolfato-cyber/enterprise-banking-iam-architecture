# Enterprise Banking IAM — User Provisioning Log

## Purpose

This document records the provisioning, validation and idempotency results for the Enterprise Banking IAM account population.

The implementation provisions a controlled population of privileged, standard and service identities into the Active Directory domain `banking.lab`.

Provisioning is performed programmatically using PowerShell and the Active Directory module. Account definitions are maintained in `employees.csv` and processed by `Import-BankingUsers.ps1`.

The evidence demonstrates:

- Controlled account provisioning
- Account classification
- OU-based identity placement
- Designated RBAC group assignment
- Account security attribute configuration
- Accidental deletion protection
- Idempotent re-execution
- Independent Active Directory validation
- RBAC membership validation

Sensitive credentials and initial account passwords are excluded from this evidence record.

## Target Environment

| Component | Value |
| --- | --- |
| Domain Controller | `AU-SYD-DC01` |
| Operating System | Windows Server 2022 |
| Domain | `banking.lab` |
| Forest Root | `banking.lab` |
| Base Distinguished Name | `DC=banking,DC=lab` |
| Directory Service | Active Directory Domain Services |
| Provisioning Method | PowerShell / Active Directory module |
| Account Definition Source | `scripts/powershell/employees.csv` |
| Provisioning Script | `scripts/powershell/Import-BankingUsers.ps1` |

## Account Population

The provisioning dataset contains 10 identities:

| Account Type | Count | Accounts |
| --- | ---: | --- |
| Privileged | 3 | `adm.jc.olfato`, `adm.syd.srv01`, `adm.syd.help01` |
| Standard | 4 | `emily.taylor`, `james.anderson`, `olivia.thomas`, `daniel.moore` |
| Service | 3 | `svc-sql-banking`, `svc-sentinel-log`, `svc-app-portal` |
| **Total** | **10** | **Controlled IAM test population** |

## Provisioning Source

The account population is defined declaratively in:

```text
scripts/powershell/employees.csv
```

The provisioning logic is implemented in:

```text
scripts/powershell/Import-BankingUsers.ps1
```

The provisioning process consumes the account definitions and creates corresponding Active Directory identities when they do not already exist. Existing identities are detected and skipped to preserve idempotent behaviour.

The implementation establishes:

- SAM account name
- User Principal Name
- Given name
- Surname
- Display name
- Account type
- Target OU
- Enabled state
- Password configuration
- Account protection attributes
- Designated RBAC group membership

Initial passwords are generated programmatically and are not recorded in repository evidence.

## Provisioning Result

The provisioning script was executed from an elevated PowerShell session on `AU-SYD-DC01`.

The provisioning implementation established the defined 10-account population within Active Directory. The resulting account population was subsequently validated against the defined account model.

| Account | Type | Target OU | Designated RBAC Group |
| --- | --- | --- | --- |
| `adm.jc.olfato` | Privileged | `Privileged_Accounts` under Tier 0 | `GG-T0-AD-Administrators` |
| `adm.syd.srv01` | Privileged | `Server_Admins` under Tier 1 | `GG-T1-Server-Administrators` |
| `adm.syd.help01` | Privileged | `Desktop_Support` under Tier 2 | `GG-T2-Desktop-Support` |
| `emily.taylor` | Standard | `Corporate_Users` | `GG-Department-Finance` |
| `james.anderson` | Standard | `Corporate_Users` | `GG-Department-HR` |
| `olivia.thomas` | Standard | `Corporate_Users` | `GG-Department-Operations` |
| `daniel.moore` | Standard | `Corporate_Users` | `GG-Department-IT` |
| `svc-sql-banking` | Service | `Service_Accounts` | `GG-Department-IT` |
| `svc-sentinel-log` | Service | `Service_Accounts` | `GG-Department-IT` |
| `svc-app-portal` | Service | `Service_Accounts` | `GG-Department-IT` |

## Post-Provisioning Identity Attribute Standardisation

Following account provisioning, the Tier 0 privileged identity `adm.jc.olfato` was standardised to align its human-readable Active Directory attributes with the established naming convention.

The stable `SamAccountName` was retained as:

```text
adm.jc.olfato
```

The following human-readable attributes were standardised:

| Attribute | Value |
| --- | --- |
| GivenName | `JC` |
| Surname | `Olfato` |
| DisplayName | `JC Olfato` |

The Active Directory object common name was also updated to:

```powershell
CN=JC Olfato
```

The resulting Distinguished Name is:

```powershell
CN=JC Olfato,OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
```

The account's `SamAccountName` and designated RBAC membership were retained unchanged.

This demonstrates separation between the stable account identifier and human-readable directory attributes, allowing display attributes to be maintained without changing the underlying account identity or RBAC assignment.

## Provisioning Validation

The resulting Active Directory state was independently validated after provisioning.

The provisioning validation process confirmed the expected account classification, OU placement, designated RBAC group and accidental deletion protection for all 10 identities.

All 10 identities returned `[VALID]` status.
Validation confirmed:

- Account type
- OU placement
- Designated RBAC group
- Accidental deletion protection

The validation completed with:

```powershell
Validation failures: 0
```

### Validation Result

| Validation Metric | Result |
| --- | ---: |
| Expected accounts | 10 |
| Accounts validated | 10 |
| Validation failures | 0 |

The provisioning validation therefore confirmed that the complete account population was deployed according to the defined account model.

## Idempotency Validation

The provisioning script was executed a second time after the account population had already been deployed.

Existing accounts were detected using their `SamAccountName` values.

The expected idempotent behaviour is:

```text
Account does not exist
        |
        v
      CREATE

Account already exists
        |
        v
       SKIP
```

The second execution returned `[SKIP]` for all 10 existing identities.
Representative output:

```powershell
[SKIP] Account already exists: adm.jc.olfato
[SKIP] Account already exists: adm.syd.srv01
[SKIP] Account already exists: adm.syd.help01
[SKIP] Account already exists: emily.taylor
[SKIP] Account already exists: james.anderson
[SKIP] Account already exists: olivia.thomas
[SKIP] Account already exists: daniel.moore
[SKIP] Account already exists: svc-sql-banking
[SKIP] Account already exists: svc-sentinel-log
[SKIP] Account already exists: svc-app-portal
```

The subsequent validation again completed with:

```powershell
Validation failures: 0
```

### Idempotency Result

| Metric | Result |
| --- | ---: |
| Existing accounts detected | 10 |
| Accounts recreated | 0 |
| Accounts skipped | 10 |
| Validation failures | 0 |

The result demonstrates that the provisioning process can be safely re-executed without creating duplicate Active Directory identities.

## Account Count Validation

The provisioned account population was independently queried from Active Directory against the defined 10-account dataset.
The validation returned:

```powershell
Count    : 10
```

### Account Count Result

| Metric | Expected | Actual | Result |
| --- | ---: | ---: | --- |
| Controlled account population | 10 | 10 | Valid |

This confirms that all 10 identities in the defined provisioning dataset are present in Active Directory.

## Account Security Attribute Validation

The account security attributes were independently queried using the Active Directory module.
The validation covered:

- `Enabled`
- `PasswordNeverExpires`
- `CannotChangePassword`
- `AccountNotDelegated`
- `ProtectedFromAccidentalDeletion`
- `PasswordLastSet`

### Privileged Accounts

| Account | Enabled | Password Never Expires | Cannot Change Password | Account Not Delegated | Accidental Deletion Protection |
| --- | --- | --- | --- | --- | --- |
| `adm.jc.olfato` | True | False | False | True | True |
| `adm.syd.srv01` | True | False | False | True | True |
| `adm.syd.help01` | True | False | False | True | True |

The privileged identities therefore retain normal password-expiry behaviour while applying the `AccountNotDelegated` and accidental-deletion protection controls defined by the account model.

### Standard Accounts

| Account | Enabled | Password Never Expires | Cannot Change Password | Account Not Delegated | Accidental Deletion Protection |
| --- | --- | --- | --- | --- | --- |
| `daniel.moore` | True | False | False | False | True |
| `emily.taylor` | True | False | False | False | True |
| `james.anderson` | True | False | False | False | True |
| `olivia.thomas` | True | False | False | False | True |

Standard accounts are not configured with non-expiring passwords or the `CannotChangePassword` restriction.

### Service Accounts

| Account | Enabled | Password Never Expires | Cannot Change Password | Account Not Delegated | Accidental Deletion Protection |
| --- | --- | --- | --- | --- | --- |
| `svc-app-portal` | True | True | True | True | True |
| `svc-sentinel-log` | True | True | True | True | True |
| `svc-sql-banking` | True | True | True | True | True |

Service identities use differentiated password and delegation controls appropriate to their non-human identity classification.

At the time of this provisioning validation, interactive-logon restrictions were deferred to the subsequent Group Policy implementation stage. Those restrictions were later implemented and independently validated as part of the completed IAM security-control architecture.

## Privileged Identity Attribute Validation

The Tier 0 privileged identity was additionally validated after its display-name standardisation.

The account retains the stable SAM identifier:

```text
adm.jc.olfato
```

while its human-readable attributes were standardised as:

| Attribute | Value |
| --- | --- |
| SamAccountName | `adm.jc.olfato` |
| GivenName | `JC` |
| Surname | `Olfato` |
| DisplayName | `JC Olfato` |
| Enabled | True |
| PasswordNeverExpires | False |
| CannotChangePassword | False |
| AccountNotDelegated | True |
| ProtectedFromAccidentalDeletion | True |

The resulting Distinguished Name confirms the Active Directory object common name was updated to:

```powershell
CN=JC Olfato,OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab
```

The `SamAccountName` and designated RBAC membership remained unchanged.

## RBAC Membership Validation

RBAC membership was independently validated using `Get-ADPrincipalGroupMembership`.

The resulting designated Global Security Group assignments were:

| Account | Designated RBAC Group |
| --- | --- |
| `adm.jc.olfato` | `GG-T0-AD-Administrators` |
| `adm.syd.srv01` | `GG-T1-Server-Administrators` |
| `adm.syd.help01` | `GG-T2-Desktop-Support` |
| `emily.taylor` | `GG-Department-Finance` |
| `james.anderson` | `GG-Department-HR` |
| `olivia.thomas` | `GG-Department-Operations` |
| `daniel.moore` | `GG-Department-IT` |
| `svc-sql-banking` | `GG-Department-IT` |
| `svc-sentinel-log` | `GG-Department-IT` |
| `svc-app-portal` | `GG-Department-IT` |

The designated RBAC group represents the project-defined role assignment for each controlled identity. It does not represent or modify the native Active Directory `primaryGroupID` attribute.

The validation confirmed that each identity has the expected designated RBAC assignment.

## Active Directory Placement Validation

The Distinguished Names returned during validation confirm that identities are located within their intended OUs.

### Privileged Identities

```powershell
adm.jc.olfato
CN=JC Olfato,OU=Privileged_Accounts,OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab

adm.syd.srv01
CN=Michael Carter,OU=Server_Admins,OU=Tier1_Server_Infrastructure,DC=banking,DC=lab

adm.syd.help01
CN=Sarah Mitchell,OU=Desktop_Support,OU=Tier2_User_Computing,DC=banking,DC=lab
```

### Standard Identities

```powershell
daniel.moore
CN=Daniel Moore,OU=Corporate_Users,OU=Tier2_User_Computing,DC=banking,DC=lab

emily.taylor
CN=Emily Taylor,OU=Corporate_Users,OU=Tier2_User_Computing,DC=banking,DC=lab

james.anderson
CN=James Anderson,OU=Corporate_Users,OU=Tier2_User_Computing,DC=banking,DC=lab

olivia.thomas
CN=Olivia Thomas,OU=Corporate_Users,OU=Tier2_User_Computing,DC=banking,DC=lab
```

### Service Identities

```powershell
svc-app-portal
CN=Service App,OU=Service_Accounts,DC=banking,DC=lab

svc-sentinel-log
CN=Service Monitor,OU=Service_Accounts,DC=banking,DC=lab

svc-sql-banking
CN=Service Backup,OU=Service_Accounts,DC=banking,DC=lab
```

The validation confirms that account placement follows the defined identity and administrative boundaries.

## Evidence Mapping

Supporting screenshots are maintained within the repository according to evidence type.

### Active Directory Users and Computers

```text
screenshots/active-directory-users/
```

| Evidence | Screenshot |
| --- | --- |
| Service Accounts | `01-service-accounts.png` |
| Privileged Accounts | `02-privileged-accounts.png` |
| Server Admins | `03-server-admins.png` |
| Corporate Users | `04-corporate-users.png` |
| Desktop Support | `05-desktop-support.png` |

These screenshots provide visual confirmation of the provisioned identities within their respective Active Directory organisational units.

### PowerShell Evidence

```text
screenshots/powershell/
```

| Evidence | Screenshot |
| --- | --- |
| User provisioning idempotency — Part A | `01A-user-provisioning-idempotency.png` |
| User provisioning idempotency — Part B | `01B-user-provisioning-idempotency.png` |

The two screenshots represent a single PowerShell evidence set split across two images for readability.

### Validation Evidence

```text
screenshots/validation/
```

| Evidence | Screenshot |
| --- | --- |
| User account validation | `01-user-account-validation.png` |
| RBAC membership validation | `02-rbac-membership-validation.png` |

These screenshots provide visual evidence supporting the independent Active Directory validation results documented above.

## Validation Summary

The completed validation activities produced the following results:

| Validation Area | Result |
| --- | --- |
| Account population | 10 identities |
| Account provisioning | Successful |
| Account validation | 10 valid / 0 failures |
| Account count | 10 |
| OU placement | Valid |
| RBAC membership | Valid |
| Account security attributes | Valid |
| Accidental deletion protection | Enabled |
| Privileged delegation protection | Enabled |
| Service-account password controls | Valid |
| Idempotent re-execution | 10 skipped / 0 recreated |
| Duplicate accounts created | 0 |
| Validation failures | 0 |

## Security Evidence Statement

The user account provisioning implementation successfully established the defined Enterprise Banking IAM identity population within Active Directory.
The evidence demonstrates that:

- The defined 10-account population exists.
- Accounts are classified and placed within the intended OUs.
- Privileged identities are separated from standard workforce identities.
- Service identities are isolated within a dedicated OU.
- Designated RBAC assignments are present.
- Account security attributes are differentiated by identity type.
- Accidental deletion protection is enabled.
- Privileged and service identities use `AccountNotDelegated = True`.
- Service identities use non-expiring password configuration as defined by the laboratory model.
- Re-execution of the provisioning process does not create duplicate accounts.
- Independent validation completed with zero failures.

Interactive-logon restrictions were implemented subsequently through Group Policy and validated as part of the completed IAM security-control architecture.

Credential rotation, managed service accounts, privileged access management and automated lifecycle workflows remain outside the implemented scope of this project.

## Repository Evidence

The implementation is supported by the following repository artefacts:

```text
scripts/powershell/employees.csv
scripts/powershell/Import-BankingUsers.ps1

configuration/user-account-model.md
documentation/identity-lifecycle-management.md

screenshots/active-directory-users/
screenshots/powershell/
screenshots/validation/
```

No passwords, secrets or other sensitive authentication material are included in the repository evidence.
