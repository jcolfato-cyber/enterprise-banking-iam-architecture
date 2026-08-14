# Role-Based Access Control Model

## Purpose

The Enterprise Banking IAM Architecture implements a Role-Based Access Control (RBAC) model using Active Directory Global Security Groups.

The model separates administrative responsibilities according to the Microsoft-inspired Tier 0, Tier 1 and Tier 2 administration framework and provides additional departmental access groups for business users.

## RBAC Design Principles

The architecture is based on:

- Least privilege
- Administrative privilege separation
- Role-based access assignment
- Security group-based authorisation
- Tiered administration
- Separation of administrative and standard user access
- Centralised identity governance

## Tier 0 — Identity Infrastructure

Tier 0 groups control access to the identity infrastructure itself.

| Security Group | Intended Role |
| --- | --- |
| GG-T0-AD-Administrators | Active Directory administration |
| GG-T0-Domain-Controllers | Domain Controller administration |
| GG-T0-Identity-Operations | Identity infrastructure operations |

Tier 0 access represents the highest administrative trust boundary because compromise of identity infrastructure can result in domain-wide compromise.

## Tier 1 — Server Infrastructure

Tier 1 groups provide administrative roles for server infrastructure.

| Security Group | Intended Role |
| --- | --- |
| GG-T1-Server-Administrators | General server administration |
| GG-T1-Infrastructure-Administrators | Infrastructure server administration |
| GG-T1-Application-Administrators | Application server administration |

Tier 1 administrators are intentionally separated from Tier 0 identity infrastructure administration.

## Tier 2 — User Computing

Tier 2 provides administrative roles for endpoint and user computing environments.

| Security Group | Intended Role |
| --- | --- |
| GG-T2-Desktop-Support | Workstation and desktop support |

Tier 2 administrative access is separated from server and identity infrastructure privileges.

## Departmental Access Groups

Departmental groups provide a controlled mechanism for assigning business-user access.

| Security Group | Intended Department |
| --- | --- |
| GG-Department-Finance | Finance |
| GG-Department-HR | Human Resources |
| GG-Department-IT | Information Technology |
| GG-Department-Operations | Operations |

Departmental membership should be assigned according to the user's business role and access requirements.

## Group Scope and Category

All project-defined groups are:

- Group Scope: Global
- Group Category: Security

Global Security Groups are used to represent organisational roles and security principals within the banking.lab domain.

## Administrative Separation

The architecture deliberately avoids placing Tier 0, Tier 1 and Tier 2 administrative roles into a single administrative security group.

This supports privilege separation and reduces the risk of excessive administrative access.

## Future Integration

The RBAC model will provide the security group foundation for subsequent stages of the project, including:

- User identity provisioning
- Administrative account separation
- Privileged access controls
- Group Policy enforcement
- Access validation
- Security event monitoring

## Validation

The RBAC architecture was validated programmatically against Active Directory.

Expected security groups: 11

Validated security groups: 11

Validation status: PASSED
