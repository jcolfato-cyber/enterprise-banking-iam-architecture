# Role-Based Access Control Model

## Purpose

The Enterprise Banking IAM Architecture implements a Role-Based Access Control (RBAC) model using Active Directory Global Security Groups.

The model separates administrative responsibilities according to a Microsoft-inspired Tier 0, Tier 1 and Tier 2 administrative framework and provides departmental security groups for business-function access.

The implemented model establishes explicit relationships between controlled identities, administrative or business roles, security groups and Active Directory organisational boundaries within the `banking.lab` domain.

## RBAC Design Principles

The architecture is based on:

- least privilege;
- administrative privilege separation;
- role-based access assignment;
- security group-based authorisation;
- tiered administration;
- separation of administrative and standard user access; and
- centralised identity governance.

## Security Group Model

The architecture contains 11 project-defined Global Security groups:

| Classification | Groups | Function |
| --- | ---: | --- |
| Tier 0 | 3 | Identity and domain administration |
| Tier 1 | 3 | Server and infrastructure administration |
| Tier 2 | 1 | Desktop support |
| Departmental | 4 | Business-function RBAC |
| **Total** | **11** | **Project-defined security groups** |

All project-defined groups use:

- Group Scope: Global
- Group Category: Security

Global Security groups represent administrative and business roles within the `banking.lab` domain.

## Tier 0 — Identity Infrastructure

Tier 0 represents the highest administrative trust boundary within the IAM architecture.

| Security Group | Intended Role |
| --- | --- |
| `GG-T0-AD-Administrators` | Active Directory administration |
| `GG-T0-Domain-Controllers` | Domain Controller administration |
| `GG-T0-Identity-Operations` | Identity infrastructure operations |

Compromise of Tier 0 administrative capability could result in control of the identity infrastructure and therefore represents the highest-impact administrative security boundary.

The controlled Tier 0 administrative identity is:

| Identity | Designated RBAC Group |
| --- | --- |
| `adm.jc.olfato` | `GG-T0-AD-Administrators` |

Tier 0 administrative access is preserved separately from the lower-trust Tier 1 and Tier 2 administrative roles.

## Tier 1 — Server Infrastructure

Tier 1 groups represent administrative roles for server and infrastructure management.

| Security Group | Intended Role |
| --- | --- |
| `GG-T1-Server-Administrators` | General server administration |
| `GG-T1-Infrastructure-Administrators` | Infrastructure server administration |
| `GG-T1-Application-Administrators` | Application server administration |

The controlled Tier 1 administrative identity is:

| Identity | Designated RBAC Group |
| --- | --- |
| `adm.syd.srv01` | `GG-T1-Server-Administrators` |

Tier 1 administration is intentionally separated from Tier 0 identity infrastructure administration.

## Tier 2 — User Computing

Tier 2 represents administrative access to workstation and end-user computing resources.

| Security Group | Intended Role |
| --- | --- |
| `GG-T2-Desktop-Support` | Workstation and desktop support |

The controlled Tier 2 administrative identity is:

| Identity | Designated RBAC Group |
| --- | --- |
| `adm.syd.help01` | `GG-T2-Desktop-Support` |

Tier 2 administrative access is separated from server and identity infrastructure privileges.

## Departmental Access Groups

Departmental groups represent business-function RBAC for standard workforce identities.

| Security Group | Intended Department |
| --- | --- |
| `GG-Department-Finance` | Finance |
| `GG-Department-HR` | Human Resources |
| `GG-Department-IT` | Information Technology |
| `GG-Department-Operations` | Operations |

The controlled standard identity assignments are:

| Identity | Department | Designated RBAC Group |
| --- | --- | --- |
| `emily.taylor` | Finance | `GG-Department-Finance` |
| `james.anderson` | Human Resources | `GG-Department-HR` |
| `olivia.thomas` | Operations | `GG-Department-Operations` |
| `daniel.moore` | Information Technology | `GG-Department-IT` |

Departmental groups provide business-role classification independently from the Tier 0, Tier 1 and Tier 2 privileged administrative model.

## Service Account RBAC

Service identities are represented separately from human administrative and standard workforce identities.

The three controlled service identities are assigned to the IT departmental security group:

| Identity | Function | Designated RBAC Group |
| --- | --- | --- |
| `svc-sql-banking` | Banking SQL service | `GG-Department-IT` |
| `svc-sentinel-log` | Security monitoring/logging service | `GG-Department-IT` |
| `svc-app-portal` | Banking application portal service | `GG-Department-IT` |

Membership in `GG-Department-IT` represents the project-defined RBAC classification for these service identities. Interactive-logon restrictions are enforced separately through Group Policy.

## Administrative Separation

The architecture deliberately avoids consolidating Tier 0, Tier 1 and Tier 2 administrative roles into a single administrative security group.

The administrative trust relationship is:

```text
Tier 0
Identity Infrastructure
        │
        ├── GG-T0-AD-Administrators
        ├── GG-T0-Domain-Controllers
        └── GG-T0-Identity-Operations

Tier 1
Server Infrastructure
        │
        ├── GG-T1-Server-Administrators
        ├── GG-T1-Infrastructure-Administrators
        └── GG-T1-Application-Administrators

Tier 2
User Computing
        │
        └── GG-T2-Desktop-Support
```

This separation establishes distinct administrative roles and supports least-privilege assignment across the IAM architecture.

## RBAC Assignment Model

Controlled identities receive a designated project RBAC group according to their administrative tier or business function.

```text
Identity
   ↓
Identity Classification
   ↓
Administrative / Business Role
   ↓
Designated Global Security Group
   ↓
Policy and Access Control
```

The designated RBAC group represents the project-defined role assignment for the controlled identity. It does not represent or modify the native Active Directory `primaryGroupID` attribute.

Group membership is provisioned through:

`scripts/powershell/Import-BankingUsers.ps1`

using the declarative identity definitions maintained in:

`scripts/powershell/employees.csv`

## Policy Enforcement

RBAC provides the identity and role foundation for subsequent policy enforcement.

The implemented Group Policy controls use security identities and administrative tiers established by the RBAC model to enforce IAM-specific logon restrictions.

In particular:

- Tier 1 and Tier 2 administrative identities are restricted from interactive and Remote Desktop logon to the Domain Controller;
- controlled service identities are restricted from interactive and Remote Desktop logon where applicable; and
- Tier 0 administrative access is preserved separately from those deny-logon assignments.

Detailed Group Policy implementation is documented in:

`gpo-security-controls.md`

## Validation

The RBAC architecture was validated against the final Active Directory environment.

| Validation | Result |
| --- | ---: |
| Expected project-defined security groups | 11 |
| Validated project-defined security groups | 11 |
| Controlled identities | 10 |
| Mandatory IAM assurance failures | 0 |

The final read-only IAM assurance framework additionally validates RBAC, privileged tiering and associated account controls through the `IAM-VAL-04`–`IAM-VAL-07` assurance checks.

Detailed final assurance results are documented in:

`iam-security-validation.md`

Provisioning evidence is maintained in:

`../evidence/rbac-provisioning-log.md`

## Related Configuration

The authoritative project-defined security-group inventory is maintained in:

`../configuration/security-groups.md`

The controlled account model and identity-to-group assignments are maintained in:

`../configuration/user-account-model.md`
