# Enterprise Banking IAM — GPO Security Controls

## Purpose

This document defines and records the implemented Group Policy security controls for the Enterprise Banking IAM Architecture.

The implementation translates the established identity-tier architecture into enforceable Windows security controls covering:

- Domain password and account-lockout policy
- Domain Controller LDAP signing enforcement
- Service-account interactive logon restrictions
- Tier 0 administrative access restrictions
- Computer-side User Rights Assignment
- GPO scope, linkage and precedence
- Effective policy validation

The implementation follows an evidence-driven control lifecycle:

### Design → Implement → Apply → Validate Effective State → Capture Evidence → Document → Close

## Scope

The Group Policy implementation applies to the `banking.lab` Active Directory laboratory environment.

### Domain

- Domain: `banking.lab`
- Domain Controller: `AU-SYD-DC01`
- Domain Controller IP: `10.10.10.10`
- Base Distinguished Name: `DC=banking,DC=lab`

### Identity Architecture

- Tier 0: `OU=Tier0_Identity_Infrastructure,DC=banking,DC=lab`
- Tier 1: `OU=Tier1_Server_Infrastructure,DC=banking,DC=lab`
- Tier 2: `OU=Tier2_User_Computing,DC=banking,DC=lab`
- Workstations: `OU=Workstations,OU=Tier2_User_Computing,DC=banking,DC=lab`
- Service Accounts: `OU=Service_Accounts,DC=banking,DC=lab`

## GPO Architecture

The implemented architecture uses the existing `Default Domain Policy` for domain account security together with three project security GPOs supporting Domain Controller security, service-account restrictions and administrative tier isolation.

| GPO | Purpose | Effective Scope | Status |
| --- | --- | --- | --- |
| `Default Domain Policy` | Domain password and account-lockout policy | `banking.lab` domain | Implemented and validated |
| `DC Security Hardening` | Domain Controller LDAP signing enforcement | `OU=Domain Controllers,DC=banking,DC=lab` | Implemented and validated |
| `GPO-SEC-Service-Account-Restrictions` | Prevent interactive logon by non-human service identities | Domain Controllers and Workstations computer OUs | Implemented and validated |
| `GPO-SEC-T0-Administrative-Restrictions` | Prevent lower-tier administrative identities from interactively accessing Tier 0 Domain Controller infrastructure | `OU=Domain Controllers,DC=banking,DC=lab` | Implemented and validated |

## Workstream 1 — Domain Account Policy

### Domain Account Policy Objective

Establish the domain-level password and account-lockout security baseline for `banking.lab`.

### Domain Account Policy Scope

`DC=banking,DC=lab`

### Implemented Password Policy

| Setting | Implemented Value |
| --- | --- |
| Enforce password history | 24 passwords |
| Maximum password age | 90 days |
| Minimum password age | 1 day |
| Minimum password length | 14 characters |
| Password complexity | Enabled |
| Reversible encryption | Disabled |

### Implemented Account Lockout Policy

| Setting | Implemented Value |
| --- | --- |
| Account lockout threshold | 5 invalid attempts |
| Account lockout duration | 30 minutes |
| Reset account lockout counter after | 30 minutes |

### Domain Account Policy Validation

The effective domain password and account-lockout policy was validated after implementation against the Active Directory domain policy.

The implemented account-lockout duration and reset window are 30 minutes, consistent with the post-implementation evidence captured when the domain policy was configured.

### Domain Account Policy Evidence

- `screenshots/group-policy/00C-current-domain-password-policy.png`
- `screenshots/group-policy/00D-post-domain-password-policy.png`

Status: `Implemented and validated`

## Workstream 2 — Domain Controller LDAP Signing

### LDAP Signing Objective

Require LDAP signing on the Domain Controller to protect LDAP communications from unsigned bind operations and strengthen integrity protection for Active Directory authentication and directory operations.

### LDAP Signing Scope

`OU=Domain Controllers,DC=banking,DC=lab`

### LDAP Signing Control

GPO:

`DC Security Hardening`

Security setting:

`Domain controller: LDAP server signing requirements`

Configured value:

`Require signing`

Effective registry state:

`LDAPServerIntegrity = 2`

### LDAP Signing Baseline

Pre-remediation inspection identified:

`LDAPServerIntegrity = 1`

The Directory Service log also recorded Event ID `2886`, indicating that LDAP signing was not being required.

### LDAP Signing GPO Precedence

During implementation, effective-state validation identified a GPO precedence conflict affecting LDAP signing.

The Domain Controllers OU link order was corrected so that `DC Security Hardening` has higher precedence than `Default Domain Controllers Policy`.

Final relevant precedence:

| Order | GPO |
| ---: | --- |
| 1 | `DC Security Hardening` |
| 2 | `Default Domain Controllers Policy` |

Following policy application, the effective security policy and NTDS registry state reported:

`LDAPServerIntegrity = 2`

### LDAP Signing Evidence

- `screenshots/group-policy/00E-pre-ldap-signing-baseline.png`
- `screenshots/group-policy/00F-ldap-signing-gpo-application-and-configuration.png`
- `screenshots/group-policy/00G-final-gpo-precedence-validation.png`

Status: `Implemented and validated`

## Workstream 3 — Service Account Interactive Logon Restrictions

### Service Account Control Objective

Prevent non-human service identities from performing interactive human logon while preserving their intended non-interactive service-account role.

### Service Identities

- `svc-sql-banking`
- `svc-sentinel-log`
- `svc-app-portal`

### Implemented User Rights Assignments

The service identities are denied:

- `Deny log on locally`
- `Deny log on through Remote Desktop Services`

Broad identity populations such as `Domain Users` were not added to the service-account-specific deny assignments.

### Service Account Computer Scope

User Rights Assignment is computer-side security policy. The `Service_Accounts` OU contains user objects and therefore cannot provide effective computer-side application of these settings.

The control was consequently applied to the computer systems on which the service identities could potentially attempt interactive logon.

The implemented computer scope is:

- `AU-SYD-DC01` — Domain Controllers OU
- `AU-SYD-W101` — Workstations OU

### Workstation OU Placement

Pre-implementation discovery identified `AU-SYD-W101` in the default:

`CN=Computers,DC=banking,DC=lab`

The existing IAM architecture already contained the intended workstation OU:

`OU=Workstations,OU=Tier2_User_Computing,DC=banking,DC=lab`

`AU-SYD-W101` was moved into this existing OU as an architectural placement correction. The service-account restriction GPO was then linked to the Workstations OU.

Final workstation distinguished name:

`CN=AU-SYD-W101,OU=Workstations,OU=Tier2_User_Computing,DC=banking,DC=lab`

### Effective-State Validation — AU-SYD-DC01

`GPO-SEC-Service-Account-Restrictions` was confirmed as an applied computer GPO.

Effective User Rights Assignment confirmed the three service identities under both:

- `SeDenyInteractiveLogonRight`
- `SeDenyRemoteInteractiveLogonRight`

### Effective-State Validation — AU-SYD-W101

`GPO-SEC-Service-Account-Restrictions` was confirmed as an applied computer GPO on the workstation.

Effective User Rights Assignment resolved the three service identities under both deny rights.

This validates the service-account control across both current computer assets in the laboratory environment.

### Evidence

- `screenshots/group-policy/02-service-account-gpo-configuration.png`
- `screenshots/group-policy/03-service-account-policy-validation.png`
- `screenshots/group-policy/04-workstation-service-account-policy-validation.png`

Status: `Implemented and validated`

## Workstream 4 — Tier 0 Administrative Restrictions

### Tier 0 Control Objective

Protect Tier 0 Domain Controller infrastructure from inappropriate interactive access by lower-tier administrative identities while preserving authorised Tier 0 administration.

### Target Computer

`AU-SYD-DC01`

### GPO

`GPO-SEC-T0-Administrative-Restrictions`

### Restricted Administrative Groups

The following lower-tier administrative groups are denied interactive access to the Domain Controller:

- `GG-T1-Server-Administrators`
- `GG-T2-Desktop-Support`

`Domain Users` was deliberately excluded from the implemented deny assignments to avoid unnecessarily broad logon restrictions.

The authorised Tier 0 group:

`GG-T0-AD-Administrators`

was not included in either deny assignment.

### Tier 0 User Rights Assignments

The Tier 0 GPO defines:

- `Deny log on locally`
- `Deny log on through Remote Desktop Services`

Because these User Rights Assignments overlap with the existing service-account restriction control, the Tier 0 GPO contains the complete required deny set:

- `GG-T1-Server-Administrators`
- `GG-T2-Desktop-Support`
- `svc-sql-banking`
- `svc-sentinel-log`
- `svc-app-portal`

This preserves the previously validated service-account restrictions while extending the effective deny policy to lower-tier administrative identities.

### Tier 0 Pre-Link Safety Validation

Before linking the GPO to the Domain Controllers OU, its configuration was validated offline.

Both deny assignments were confirmed to contain the intended five principals.

The following privileged principals were confirmed absent from the deny assignments:

- `GG-T0-AD-Administrators`
- `Domain Admins`
- `Enterprise Admins`
- `Administrators`

The GPO was linked only after this safety validation passed.

### Tier 0 Effective-State Validation

Following GPO application, `gpresult` confirmed the Tier 0 restriction GPO as an applied computer policy on `AU-SYD-DC01`.

Effective User Rights Assignment confirmed both:

`SeDenyInteractiveLogonRight`

and:

`SeDenyRemoteInteractiveLogonRight`

contain:

- `GG-T1-Server-Administrators`
- `GG-T2-Desktop-Support`
- `svc-sql-banking`
- `svc-sentinel-log`
- `svc-app-portal`

Membership validation separately confirmed:

`adm.jc.olfato`

remains a member of:

`GG-T0-AD-Administrators`

The Tier 0 administrative group is absent from the effective deny assignments.

No interactive authentication attempt using a service identity or lower-tier administrative identity was required to validate the control.

### Tier 0 Remote Desktop Access Control

The Tier 0 control defines `Deny log on through Remote Desktop Services` as an IAM access restriction for lower-tier administrative identities.

The control does not depend on Remote Desktop Services being enabled or disabled. Its purpose is to ensure that the defined lower-tier administrative groups remain denied RDP interactive logon to Tier 0 Domain Controller infrastructure whenever the service is available.

The service identities remain subject to the corresponding RDP deny right through the effective User Rights Assignment.

Remote Desktop service exposure is treated separately from the IAM access restriction itself.

### Tier 0 Control Evidence

- `screenshots/group-policy/05-tier0-gpo-configuration.png`
- `screenshots/group-policy/06-tier0-administrative-restrictions-validation.png`

Status: `Implemented and validated`

## Domain-Level GPO Precedence

The domain-level account policy is provided through the existing `Default Domain Policy`.

Final domain link order for:

`DC=banking,DC=lab`

is:

| Order | GPO | Enabled | Enforced |
| ---: | --- | --- | --- |
| 1 | `Default Domain Policy` | Yes | No |

The `Default Domain Policy` provides the validated domain password and account-lockout settings documented in Workstream 1.

## Final Domain Controllers GPO Precedence

The final GPO link order for:

`OU=Domain Controllers,DC=banking,DC=lab`

is:

| Order | GPO | Enabled | Enforced |
| ---: | --- | --- | --- |
| 1 | `DC Security Hardening` | Yes | No |
| 2 | `Default Domain Controllers Policy` | Yes | No |
| 3 | `GPO-SEC-T0-Administrative-Restrictions` | Yes | No |
| 4 | `GPO-SEC-Service-Account-Restrictions` | Yes | No |

`DC Security Hardening` retains the highest link precedence to preserve the validated LDAP signing configuration.

`GPO-SEC-T0-Administrative-Restrictions` has higher precedence than `GPO-SEC-Service-Account-Restrictions` for the overlapping deny User Rights Assignments and contains the complete five-principal deny set.

## Pre-Implementation Environment Assessment

A pre-implementation inspection was performed against the `banking.lab` Active Directory environment before the security controls were implemented.

The assessment established:

- Existing GPO inventory
- Existing OU hierarchy
- Existing computer-object locations
- Existing Tier 0, Tier 1 and Tier 2 group membership
- Existing service identities
- Existing User Rights Assignment
- Existing domain password policy
- Existing LDAP signing state
- Existing Remote Desktop Services state

### Initial Computer Placement

At the time of baseline assessment:

- `AU-SYD-DC01` was located in `OU=Domain Controllers,DC=banking,DC=lab`
- `AU-SYD-W101` was located in `CN=Computers,DC=banking,DC=lab`

The existing `Workstations` OU was empty.

During implementation, `AU-SYD-W101` was moved into the existing Workstations OU to align the computer object with the established Tier 2 OU architecture and provide an appropriate computer-side GPO scope.

Historical evidence remains unchanged and continues to represent the environment state at the time it was captured.

### Remote Desktop Baseline

Remote Desktop Services on `AU-SYD-DC01` were identified as disabled during baseline assessment.

The host reported:

- `fDenyTSConnections = 1`
- Remote Desktop firewall rules disabled
- No TCP/3389 listener detected

This represents the pre-implementation state captured at the time of the baseline assessment.

Subsequent assurance validation identified that `DC Security Hardening` currently configures:

```powershell
fDenyTSConnections = 0
```

and that TCP/3389 is listening locally on `AU-SYD-DC01`.

The standard Remote Desktop firewall rules remain disabled, and independent network validation from `au-syd-secops01` observed TCP/3389 as filtered.

RDP therefore remains relevant both as an administrative access mechanism and as a potential attacker-facing service. The implemented service-account and lower-tier administrative deny User Rights Assignments provide defence-in-depth IAM restrictions independently of the service exposure state.

This final RDP exposure state is retained as a residual assurance observation. It does not represent a mandatory IAM control failure because the implemented deny User Rights Assignments remain effective independently of RDP service exposure.

The final assurance result is documented in:

`iam-security-validation.md`

## Evidence Register

| Evidence | Control Objective |
| --- | --- |
| `00A-pre-gpo-ad-baseline.png` | Pre-implementation Active Directory and GPO baseline |
| `00B-pre-security-policy-rdp-baseline.png` | Pre-implementation security policy and RDP baseline |
| `00C-current-domain-password-policy.png` | Existing domain password-policy state |
| `00D-post-domain-password-policy.png` | Effective post-implementation domain password policy |
| `00E-pre-ldap-signing-baseline.png` | Pre-remediation LDAP signing state |
| `00F-ldap-signing-gpo-application-and-configuration.png` | LDAP signing GPO configuration and application |
| `00G-final-gpo-precedence-validation.png` | Final LDAP signing and GPO precedence validation |
| `01-gpo-link-validation.png` | Domain Controller GPO linkage validation |
| `02-service-account-gpo-configuration.png` | Service-account deny-right configuration |
| `03-service-account-policy-validation.png` | Effective service-account restriction validation on `AU-SYD-DC01` |
| `04-workstation-service-account-policy-validation.png` | Effective service-account restriction validation on `AU-SYD-W101` |
| `05-tier0-gpo-configuration.png` | Tier 0 administrative restriction GPO configuration |
| `06-tier0-administrative-restrictions-validation.png` | Effective Tier 0 restriction and Tier 0 identity preservation validation |

## Implementation Status

| Capability | Status |
| --- | --- |
| GPO architecture and design | Complete |
| Domain account policy | Implemented and validated |
| LDAP signing enforcement | Implemented and validated |
| Service-account restrictions — Domain Controller | Implemented and validated |
| Service-account restrictions — Workstation | Implemented and validated |
| Tier 0 administrative restrictions | Implemented and validated |
| Computer-side GPO scope | Implemented and validated |
| GPO precedence | Validated |
| Effective policy validation | Complete |
| Evidence capture | Complete |
| Technical implementation | Complete |

## Implementation Boundary

This implementation provides Group Policy controls directly supporting the IAM and privileged-access architecture.

Broader Windows endpoint and server hardening controls—including application restrictions, PowerShell or command-shell restrictions, Registry Editor restrictions, removable-media controls, endpoint security baselines and user-environment restrictions—are outside the scope of this IAM implementation and are reserved for subsequent enterprise security-hardening work.

Interactive logon notices are likewise not included as part of the IAM control set.

This boundary keeps the implementation focused on identity security, authentication policy, privileged-access segmentation and non-human identity controls rather than expanding the project into a general Windows hardening baseline.

## Implementation Closure

All approved IAM Group Policy control workstreams have been implemented and validated:

1. Domain password and account-lockout policy
2. Domain Controller LDAP signing enforcement
3. Service-account interactive logon restrictions
4. Tier 0 administrative access restrictions

Effective-state validation has been completed across the applicable Domain Controller and workstation assets, and the corresponding implementation evidence has been captured.

### Technical control implementation: COMPLETE
