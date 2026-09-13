# Automation and Validation Scripts

## Purpose

This directory contains the PowerShell automation and validation tooling used
to implement and assure the identity architecture within the `banking.lab`
Active Directory environment.

The scripts support four distinct functions:

- Organisational Unit provisioning
- Role-Based Access Control group provisioning
- Controlled identity provisioning and RBAC assignment
- Read-only IAM security assurance

The automation follows the project implementation sequence while maintaining a
clear separation between scripts that modify Active Directory state and the
assurance framework used to validate the completed architecture.

## Directory Structure

```text
scripts/
├── README.md
└── powershell/
    ├── Import-BankingUsers.ps1
    ├── New-BankingOU.ps1
    ├── New-BankingSecurityGroups.ps1
    ├── Test-BankingIAMArchitecture.ps1
    └── employees.csv
```

## Script Inventory

| Artefact | Function | Execution Behaviour |
| --- | --- | --- |
| `New-BankingOU.ps1` | Provisions the tiered Active Directory OU architecture | State-changing |
| `New-BankingSecurityGroups.ps1` | Provisions the project-defined RBAC security groups | State-changing |
| `Import-BankingUsers.ps1` | Provisions controlled identities and assigns designated RBAC membership | State-changing |
| `Test-BankingIAMArchitecture.ps1` | Independently validates the completed IAM architecture | Read-only |
| `employees.csv` | Defines the controlled identity population and provisioning attributes | Declarative input |

## Execution Sequence

The provisioning scripts were used in the following logical sequence:

```text
New-BankingOU.ps1
        ↓
New-BankingSecurityGroups.ps1
        ↓
Import-BankingUsers.ps1
        ↓
Group Policy Security Controls
(manual / GPMC implementation)
        ↓
Test-BankingIAMArchitecture.ps1
```

Group Policy security controls were implemented separately from the provisioning scripts and are documented in:

`../documentation/gpo-security-controls.md`

The final assurance framework validates the resulting integrated IAM state without modifying the environment.

## Organisational Unit Provisioning

**`New-BankingOU.ps1`**

`New-BankingOU.ps1` provisions the tiered Organisational Unit architecture used to separate identity and infrastructure objects within `banking.lab`.

The script defines the required Tier 0, Tier 1, Tier 2 and service-account OU structure and creates the required OUs beneath:

`DC=banking,DC=lab`

The implemented architecture contains 14 project-defined OUs.

Provisioned OUs are configured with accidental-deletion protection to reduce the risk of unintended structural changes.

The script was designed to recognise existing target OUs before attempting creation, supporting repeatable provisioning without intentionally duplicating the defined OU structure.

Detailed implementation evidence is maintained in:

`../evidence/ou-provisioning-log.md`

## Security Group Provisioning

**`New-BankingSecurityGroups.ps1`**

`New-BankingSecurityGroups.ps1` provisions the security groups supporting the project RBAC architecture.

The script creates 11 project-defined groups across the Tier 0, Tier 1, Tier 2 and departmental security domains.

The project groups are configured as:

- Group category: Security
- Group scope: Global
- Placement: designated administrative or departmental OU

The provisioned groups support separation between privileged administrative tiers and standard departmental access.

The script checks the designated target OU for an existing group before attempting creation, supporting repeatable execution within the intended provisioning scope.

Detailed RBAC design and provisioning evidence are maintained in:

`../documentation/rbac-model.md`

`../evidence/rbac-provisioning-log.md`

## Identity Provisioning

**`Import-BankingUsers.ps1`**

`Import-BankingUsers.ps1` provisions the controlled project identity population from the declarative `employees.csv` dataset.

The controlled population consists of:

| Identity Type | Count |
| --- | ---: |
| Privileged | 3 |
| Standard | 4 |
| Service | 3 |
| **Total** | **10** |

For each identity definition, the script manages the required Active Directory attributes, target OU placement and designated project RBAC membership.

The provisioning model distinguishes between standard, privileged and service identities and applies the persistent account characteristics required for each identity type.

Examples include:

- privileged identities configured as non-delegable;
- service identities configured for non-human account operation;
- accidental-deletion protection applied to controlled identities; and
- designated project RBAC membership assigned during provisioning.

Interactive logon restrictions for service identities are not implemented by this script. Those controls are enforced separately through Group Policy.

## Idempotent Provisioning

Identity discovery is based on `SamAccountName`.

The provisioning behaviour is:

```text
Account does not exist → CREATE
Account already exists → SKIP
```

This allows the provisioning workflow to be rerun without intentionally creating duplicate controlled identities.

Historical implementation validation confirmed a second provisioning execution in which all 10 existing project identities were detected and skipped without provisioning-validation failures.

Detailed implementation evidence is maintained in:

`../evidence/user-provisioning-log.md`

**`employees.csv`**

`employees.csv` is the declarative identity dataset consumed by `Import-BankingUsers.ps1`.

It defines the controlled project population and associated provisioning attributes, including:

- employee or service identifier;
- name;
- `SamAccountName`;
- department;
- job title;
- account type;
- target OU;
- designated RBAC group; and
- enabled state.

The `PrimaryGroup` field in the dataset represents the designated project RBAC security group. It does not represent the native Active Directory `primaryGroupID` attribute.

The CSV contains the authoritative 10-identity project population used for provisioning and subsequent assurance.

## IAM Security Assurance

**`Test-BankingIAMArchitecture.ps1`**

`Test-BankingIAMArchitecture.ps1` is the independent read-only assurance framework for the completed IAM architecture.

Unlike the provisioning scripts, it does not create, modify, move or remediate Active Directory objects or Group Policy configuration.

Its purpose is to answer the assurance question:

```text
Does the final banking.lab implementation conform to the IAM architecture claimed by the project?
```

The framework validates the deployed environment across 16 assurance identifiers:

| Validation Range | Assurance Area |
| --- | --- |
| `IAM-VAL-01`–`IAM-VAL-03` | OU architecture, identity population and classification |
| `IAM-VAL-04`–`IAM-VAL-07` | RBAC, privileged tiering and account controls |
| `IAM-VAL-08`–`IAM-VAL-10` | GPO architecture, precedence and domain account policy |
| `IAM-VAL-11`–`IAM-VAL-14` | LDAP signing, logon restrictions, Tier 0 protection and RDP exposure |
| `IAM-VAL-15` | Provisioning integrity |
| `IAM-VAL-16` | Aggregate architecture conformance |

## Assurance Views

The framework provides focused output views for different assurance domains.

Architecture validation:

```powershell
.\Test-BankingIAMArchitecture.ps1 -View Architecture
```

Security-policy validation:

```powershell
.\Test-BankingIAMArchitecture.ps1 -View Security
```

Consolidated assurance summary:

```powershell
.\Test-BankingIAMArchitecture.ps1 -View Summary
```

## Result Classification

The assurance framework uses three result states:

| Result | Meaning |
| --- | --- |
| `PASS` | Observed state satisfies the defined architecture requirement |
| `FAIL` | Observed state contradicts the defined architecture requirement |
| `WARN` | An observation requires review but does not establish non-conformance |

The framework does not automatically remediate a failed or unexpected state.

A genuine failure requires deliberate investigation, classification, remediation where appropriate and subsequent retesting.

## Final Assurance Result

The completed architecture produced:

| Result | Count |
| --- | ---: |
| PASS | 14 |
| FAIL | 0 |
| WARN | 2 |

Overall result: **`WARN`**

There are zero mandatory IAM assurance failures.

`IAM-VAL-14 — RDP Exposure` represents the single residual technical observation. RDP is enabled and listening locally on `AU-SYD-DC01`, while the standard Remote Desktop firewall rules remain disabled. Independent network validation from `au-syd-secops01` observed TCP/3389 as filtered.

`IAM-VAL-16 — Architecture Conformance` inherits the WARN state as the aggregate architecture result and does not represent a second independent technical deficiency.

Detailed assurance methodology, results and evidence are maintained in:

`../documentation/iam-security-validation.md`

## Provisioning and Assurance Boundary

The repository deliberately separates implementation tooling from assurance tooling.

The following scripts can change Active Directory state:

- `New-BankingOU.ps1`
- `New-BankingSecurityGroups.ps1`
- `Import-BankingUsers.ps1`

The following script is read-only:

- `Test-BankingIAMArchitecture.ps1`

This separation prevents the assurance framework from silently changing the environment it is intended to evaluate.

Group Policy configuration is also outside the provisioning scripts and is documented independently.

The resulting control lifecycle is:

### Provision → Enforce → Assure

## Execution Requirements

The PowerShell scripts are intended for execution within the controlled `banking.lab` laboratory environment.

Relevant requirements include:

- Windows PowerShell;
- Active Directory PowerShell module;
- appropriate Active Directory administrative permissions for provisioning operations;
- connectivity to the `banking.lab` domain; and
- access to the required declarative input files.

State-changing scripts should be reviewed before execution and used only against an environment for which the operator has appropriate administrative authority.

The assurance script should be executed from a context capable of reading the required Active Directory, Group Policy and local security-policy state.

## Safety and Operational Notes

The scripts are laboratory automation and assurance artefacts designed for the Enterprise Banking IAM Architecture project.

They should not be treated as production deployment tooling without independent review, testing and adaptation to the target organisation.

The repository does not store or expose project account passwords.

Provisioning credentials and temporary authentication material should not be committed to source control.

Historical evidence should remain distinct from current-state assurance. A later validation result should not be used to silently rewrite or reinterpret earlier implementation evidence.
