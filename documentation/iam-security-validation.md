# IAM Security Validation

## Purpose

This document records the final security-assurance validation of the
`banking.lab` identity and access management architecture.

The validation was performed after completion of the organisational unit
architecture, RBAC model, identity provisioning and Group Policy security
controls. Its purpose is to determine whether the deployed Active Directory
environment conforms to the IAM architecture implemented by the project.

The assurance process follows the project methodology:

### DESIGN → IMPLEMENT → APPLY → VALIDATE → CAPTURE EVIDENCE → DOCUMENT → CLOSE

The validation activity is assurance-focused and does not automatically
remediate detected configuration differences.

## Validation Scope

The assurance scope includes:

- Active Directory organisational unit architecture
- controlled IAM identity population
- identity classification and OU placement
- RBAC security groups and membership
- privileged administrative tier separation
- privileged account security attributes
- service-account security attributes
- Group Policy architecture and precedence
- effective domain password and account-lockout policy
- LDAP signing enforcement
- effective interactive-logon restrictions
- Tier 0 administrative protection
- Remote Desktop exposure state
- provisioning integrity
- aggregate IAM architecture conformance

The controlled IAM population consists of ten project identities:

| Identity Type | Count |
| --- | ---: |
| Privileged | 3 |
| Standard | 4 |
| Service | 3 |
| **Total** | **10** |

Built-in Active Directory accounts and other operating-system identities are
outside the controlled project identity population.

## Validation Environment

| Component | Value |
| --- | --- |
| Domain | `banking.lab` |
| Domain Controller | `AU-SYD-DC01` |
| Domain Controller IP | `10.10.10.10` |
| Corporate Workstation | `AU-SYD-W101` |
| Security Validation Host | `au-syd-secops01` |
| Validation Script | `Test-BankingIAMArchitecture.ps1` |
| Declarative Identity Source | `employees.csv` |

The primary assurance script was executed locally on `AU-SYD-DC01`.

A supplementary network-exposure validation was performed independently from
`au-syd-secops01`.

## Validation Methodology

The assurance script performs read-only validation of Active Directory,
Group Policy, effective security policy, registry state and local network
exposure indicators.

The script does not create, modify, move or remove Active Directory objects,
security groups, Group Policy objects or IAM configuration.

Where effective security state is authoritative, validation is performed
against the effective configuration rather than by performing unnecessary
interactive logon attempts.

Effective User Rights Assignment was inspected using a temporary security
policy export. The temporary export was used only for validation and did not
modify the IAM control plane.

Validation results use the following states:

| Status | Meaning |
| --- | --- |
| PASS | Observed state satisfies the defined assurance criterion |
| FAIL | Observed state contradicts a mandatory IAM requirement |
| WARN | Observed state requires review but does not establish IAM non-conformance |

## Validation Criteria and Results

| ID | Assurance Domain | Result | Validated State |
| --- | --- | --- | --- |
| IAM-VAL-01 | OU Architecture | PASS | All 14 required OUs exist at the expected distinguished names with accidental-deletion protection enabled |
| IAM-VAL-02 | Identity Population | PASS | All 10 controlled project identities exist with no additional user objects in the controlled identity OUs |
| IAM-VAL-03 | Identity Classification | PASS | All controlled identities match their declarative OU placement and core directory attributes |
| IAM-VAL-04 | RBAC | PASS | All 11 project RBAC groups conform and controlled identities retain their designated project RBAC membership |
| IAM-VAL-05 | Privileged Tiering | PASS | Tier 0, Tier 1 and Tier 2 controlled administrative identities remain separated with no project cross-tier membership |
| IAM-VAL-06 | Privileged Account Controls | PASS | All three privileged identities retain the approved persistent account-security controls |
| IAM-VAL-07 | Service Accounts | PASS | All three service identities retain the approved non-human account-security controls |
| IAM-VAL-08 | GPO Architecture | PASS | Required GPOs exist, Default Domain Policy is linked at domain scope and the four approved Domain Controllers GPOs are linked and enabled |
| IAM-VAL-09 | GPO Precedence | PASS | Domain Controllers GPO precedence remains in the approved order |
| IAM-VAL-10 | Domain Account Policy | PASS | Effective domain password and account-lockout policy matches the implemented configuration |
| IAM-VAL-11 | LDAP Signing | PASS | Effective `LDAPServerIntegrity` remains `2` |
| IAM-VAL-12 | Service Logon Restriction | PASS | All three service identities remain in both effective interactive-logon deny rights |
| IAM-VAL-13 | Tier 0 Protection | PASS | Tier 1 and Tier 2 administrators remain denied while Tier 0 administration is excluded from the deny assignments |
| IAM-VAL-14 | RDP Exposure | WARN | RDP is enabled and listening locally, while Remote Desktop firewall rules remain disabled |
| IAM-VAL-15 | Provisioning Integrity | PASS | Declarative identity definitions remain internally consistent and each controlled `SamAccountName` resolves to one deployed identity |
| IAM-VAL-16 | Architecture Conformance | WARN | No mandatory IAM validation failed; aggregate result inherits the residual RDP exposure observation |

## Organisational Unit Validation

The validator confirmed the complete fourteen-OU IAM hierarchy under
`banking.lab`.

All required OUs exist at their documented distinguished names and retain
`ProtectedFromAccidentalDeletion=True`.

The final workstation placement was also retained:

```text

CN=AU-SYD-W101,OU=Workstations,OU=Tier2_User_Computing,DC=banking,DC=lab

```

This placement reflects the final deployed architecture.

## Identity Population and Classification

All ten controlled IAM identities were resolved successfully.
The deployed population remains:

| Classification | Expected | Validated |
| --- | ---: | ---: |
| Privileged | 3 | 3 |
| Standard | 4 | 4 |
| Service | 3 | 3 |
| **Total** | **10** | **10** |

Identity placement was compared against the declarative definitions in `employees.csv`.
No expected controlled identity was missing.

## RBAC Validation

All eleven project-defined RBAC groups were validated for:

- existence
- expected OU placement
- Global group scope
- Security group category
- controlled-identity membership

The three controlled privileged identities remain mapped to their respective
administrative tiers:

| Tier | Identity | Project RBAC Group |
| --- | --- | --- |
| Tier 0 | `adm.jc.olfato` | `GG-T0-AD-Administrators` |
| Tier 1 | `adm.syd.srv01` | `GG-T1-Server-Administrators` |
| Tier 2 | `adm.syd.help01` | `GG-T2-Desktop-Support` |

No cross-tier project membership was detected among the controlled privileged identities.

## Privileged Account Validation

The three privileged identities retain the required persistent controls,
including:

- enabled account state
- `AccountNotDelegated=True`
- password-expiration behaviour consistent with the privileged account model
- user password-change capability consistent with the account model
- accidental-deletion protection
- correct administrative OU placement
- correct tier-specific RBAC membership

## Service Account Validation

The following service identities were validated:

```text
svc-sql-banking
svc-sentinel-log
svc-app-portal
```

Each service identity remains:

- enabled
- located in `OU=Service_Accounts,DC=banking,DC=lab`
- configured with `PasswordNeverExpires=True`
- configured with `CannotChangePassword=True`
- configured with `AccountNotDelegated=True`
- protected from accidental deletion
- assigned to the expected project RBAC group

Interactive-logon restrictions were validated separately through effective
User Rights Assignment.

## Group Policy Validation

The deployed Group Policy architecture contains the required policies for the implemented IAM design.
At domain scope:

```text
Default Domain Policy
```

At the Domain Controllers OU:

```text
Order 1  DC Security Hardening
Order 2  Default Domain Controllers Policy
Order 3  GPO-SEC-T0-Administrative-Restrictions
Order 4  GPO-SEC-Service-Account-Restrictions
```

The final precedence was independently revalidated and matches the effective architecture established during implementation.

## Domain Account Policy Validation

The effective domain account policy was validated as:

| Control | Effective State |
| --- | --- |
| Minimum password length | 14 characters |
| Password complexity | Enabled |
| Password history | 24 passwords |
| Maximum password age | 90 days |
| Minimum password age | 1 day |
| Account lockout threshold | 5 attempts |
| Account lockout duration | 30 minutes |
| Account lockout reset window | 30 minutes |
| Reversible encryption | Disabled |

The assurance exercise confirmed that the implemented lockout duration and reset window are 30 minutes.
This value is consistent with the implementation evidence captured when the domain policy was configured.

## LDAP Signing Validation

LDAP signing enforcement remains effective on `AU-SYD-DC01`.
The effective registry state is:

```text
LDAPServerIntegrity = 2
```

This corresponds to requiring LDAP signing.
The validated precedence of `DC Security Hardening` continues to preserve this effective setting.

## Interactive Logon Restriction Validation

Effective User Rights Assignment confirms that all three service identities remain included in:

```text
SeDenyInteractiveLogonRight
SeDenyRemoteInteractiveLogonRight
```

The effective Tier 0 administrative restriction set contains:

```text
GG-T1-Server-Administrators
GG-T2-Desktop-Support
svc-sql-banking
svc-sentinel-log
svc-app-portal
```

The Tier 0 project group remains absent from the deny assignments.
This preserves the intended administrative tier model without requiring interactive logon attempts using restricted identities.

## Remote Desktop Exposure Validation

The local validation on `AU-SYD-DC01` identified the following state:

```text
fDenyTSConnections = 0
TCP/3389 listening locally
Remote Desktop firewall rules disabled
```

Because RDP is locally enabled and listening, `IAM-VAL-14` is retained as a
WARN observation rather than being reported as an IAM control failure.
The IAM-specific controls governing RDP access remain effective through
`IAM-VAL-12` and `IAM-VAL-13`.
An independent network validation was performed from `au-syd-secops01` using:

```text
nmap -Pn -p 53,88,135,139,389,445,464,636,3268,3269,3389 10.10.10.10
```

The domain controller responded with the expected Active Directory services
available while TCP/3389 was observed as:

```text
3389/tcp filtered
```

This indicates that the RDP listener was not reachable from the controlled security-testing host during the validation exercise.
The Nmap result is supplementary network evidence and is not generated by the local IAM assurance script.

## Provisioning Integrity Validation

The assurance script did not rerun the state-capable identity provisioning script.
Instead, provisioning integrity was validated read-only by confirming that:

- the declarative dataset contains the expected ten identities
- expected `SamAccountName` values are unique
- deployed identities resolve uniquely
- deployed identity attributes conform to the declarative source
- no duplicate controlled project identity was identified

Historical provisioning evidence separately demonstrates that a previous second execution of the provisioning workflow detected all ten existing identities and skipped their recreation.

## Findings

No mandatory IAM assurance control failed.
One residual observation remains:

### RDP Exposure — WARN

RDP is locally enabled and TCP/3389 is listening on `AU-SYD-DC01`. The Remote Desktop firewall rules remain disabled, and independent validation from `au-syd-secops01` observed TCP/3389 as filtered.
This observation does not invalidate the implemented IAM architecture.
Effective service-account and lower-tier administrative RDP deny rights remain in force.
The aggregate `IAM-VAL-16` result is therefore WARN because it inherits this single residual observation.

## Evidence Register

| Evidence | Purpose |
| --- | --- |
| `screenshots/validation/03-final-iam-architecture-validation.png` | Final OU, identity, RBAC, privileged-tier and provisioning-integrity assurance |
| `screenshots/validation/04-final-gpo-security-validation.png` | Final GPO, account-policy, LDAP-signing, logon-restriction, Tier 0 and RDP assurance |
| `screenshots/validation/05-final-iam-assurance-summary.png` | Consolidated IAM-VAL-01 through IAM-VAL-16 assurance result |
| `screenshots/group-policy/00D-post-domain-password-policy.png` | Historical evidence of implemented domain password and account-lockout policy |
| `screenshots/group-policy/00F-ldap-signing-gpo-application-and-configuration.png` | LDAP signing implementation and effective-state evidence |
| `screenshots/group-policy/00G-final-gpo-precedence-validation.png` | Final validated DC GPO precedence |
| `screenshots/group-policy/03-service-account-policy-validation.png` | Effective service-account deny-right validation on the domain controller |
| `screenshots/group-policy/04-workstation-service-account-policy-validation.png` | Effective service-account deny-right validation on the corporate workstation |
| `screenshots/group-policy/06-tier0-administrative-restrictions-validation.png` | Effective Tier 0 administrative restriction validation |

## Assurance Conclusion

The final assurance exercise found no failed mandatory IAM controls. The deployed `banking.lab` environment conforms to the implemented identity architecture across organisational structure, controlled identity population, RBAC, administrative tiering, privileged and service-account controls, Group Policy architecture, account policy, LDAP signing, effective interactive-logon restrictions and provisioning integrity.

Fourteen validation checks returned PASS.

One technical observation, `IAM-VAL-14`, returned WARN because RDP is enabled and listening locally, while independent validation from the controlled security-testing segment observed TCP/3389 as filtered.

`IAM-VAL-16` inherits this WARN state as the aggregate architecture-conformance result.

The validation therefore concludes that the implemented IAM architecture remains operational and materially conforms to its defined IAM security objectives, with the documented RDP exposure observation retained for transparency and future review.
