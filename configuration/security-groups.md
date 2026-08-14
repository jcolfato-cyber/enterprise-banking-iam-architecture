# Security Group Configuration

## Domain

`banking.lab`

## Security Group Inventory

| Group | Scope | Category | Tier / Function | Target OU |
| --- | --- | --- | --- | --- |
| GG-T0-AD-Administrators | Global | Security | Tier 0 | Administrative_Groups |
| GG-T0-Domain-Controllers | Global | Security | Tier 0 | Administrative_Groups |
| GG-T0-Identity-Operations | Global | Security | Tier 0 | Administrative_Groups |
| GG-T1-Server-Administrators | Global | Security | Tier 1 | Server_Admins |
| GG-T1-Infrastructure-Administrators | Global | Security | Tier 1 | Server_Admins |
| GG-T1-Application-Administrators | Global | Security | Tier 1 | Server_Admins |
| GG-T2-Desktop-Support | Global | Security | Tier 2 | Desktop_Support |
| GG-Department-Finance | Global | Security | Department | Department_Groups |
| GG-Department-HR | Global | Security | Department | Department_Groups |
| GG-Department-IT | Global | Security | Department | Department_Groups |
| GG-Department-Operations | Global | Security | Department | Department_Groups |

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
