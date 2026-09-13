# Security Group Configuration

## Domain

`banking.lab`

## Purpose

This configuration defines the 11 project-controlled Global Security groups used to support the tiered administrative and departmental Role-Based Access Control model within `banking.lab`.

The complete group inventory is maintained here as configuration reference. The project architecture diagram presents selected groups and relationships to communicate the IAM control model without reproducing the complete Active Directory group inventory.

## Security Group Inventory

| Group | Scope | Category | Tier / Function | Target OU |
| --- | --- | --- | --- | --- |
| `GG-T0-AD-Administrators` | Global | Security | Tier 0 | `Administrative_Groups` |
| `GG-T0-Domain-Controllers` | Global | Security | Tier 0 | `Administrative_Groups` |
| `GG-T0-Identity-Operations` | Global | Security | Tier 0 | `Administrative_Groups` |
| `GG-T1-Server-Administrators` | Global | Security | Tier 1 | `Server_Admins` |
| `GG-T1-Infrastructure-Administrators` | Global | Security | Tier 1 | `Server_Admins` |
| `GG-T1-Application-Administrators` | Global | Security | Tier 1 | `Server_Admins` |
| `GG-T2-Desktop-Support` | Global | Security | Tier 2 | `Desktop_Support` |
| `GG-Department-Finance` | Global | Security | Department | `Department_Groups` |
| `GG-Department-HR` | Global | Security | Department | `Department_Groups` |
| `GG-Department-IT` | Global | Security | Department | `Department_Groups` |
| `GG-Department-Operations` | Global | Security | Department | `Department_Groups` |

## Security Tier Summary

| Classification | Groups | Function |
| --- | ---: | --- |
| Tier 0 | 3 | Identity and domain administration |
| Tier 1 | 3 | Server and infrastructure administration |
| Tier 2 | 1 | Desktop support |
| Departmental | 4 | Business-function RBAC |
| **Total** | **11** | **Project-controlled security groups** |

The tier classification represents administrative trust boundaries. Departmental groups provide business-function RBAC and are not additional privileged administrative tiers.

## Validation

Total project-defined security groups:

`11`

Validation command:

```powershell
Get-ADGroup -Filter * |
    Where-Object {$_.Name -like "GG-*"} |
    Measure-Object
```

### Validation Result

```powershell
Count    : 11
```

The validation result confirms the expected project-defined `GG-*` group population within the controlled lab environment.

## Related Documentation

Detailed RBAC design, identity-to-group relationships and implementation evidence are maintained in:

- `../documentation/rbac-model.md`
- `../evidence/rbac-provisioning-log.md`
- `../scripts/powershell/New-BankingSecurityGroups.ps1`
