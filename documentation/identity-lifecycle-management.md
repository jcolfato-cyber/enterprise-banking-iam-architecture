# Enterprise Banking IAM — Identity Lifecycle Management

## Purpose

This document defines the identity lifecycle management model for the Enterprise Banking IAM Architecture.

The lifecycle model establishes controlled processes for identity creation, modification, access assignment, review, suspension and removal.

The objective is to ensure that identities receive appropriate access throughout their lifecycle while reducing the risk of excessive, unauthorised or orphaned access.

The model is aligned with the principles of least privilege, role-based access control, administrative separation and controlled identity governance.

---

## Lifecycle Model

The identity lifecycle is represented by the following process:

```text
Identity Requirement
        |
        v
   Provisioning
        |
        v
   Access Assignment
        |
        v
   Active Identity
        |
        +-------------------+
        |                   |
        v                   v
   Role Change          Access Review
        |                   |
        v                   |
   Modification <-----------+
        |
        v
   Suspension
        |
        v
   Deprovisioning
        |
        v
   Identity Removal
```

Each lifecycle stage has defined security objectives and administrative controls.

---

## Lifecycle Stages

### 1. Identity Request

Identity creation begins with a defined business or operational requirement.
The request should establish:

- Identity owner
- Employee or service identifier
- Account type
- Business department or operational function
- Required role
- Administrative tier, where applicable
- Target OU
- Required RBAC group
- Account lifecycle requirements

Human identities and non-human service identities are treated as separate identity classes.
Privileged identities require additional administrative justification because they provide elevated access.

### 2. Identity Provisioning

Identity provisioning creates the Active Directory account according to the approved account definition.
The Enterprise Banking IAM implementation uses a declarative CSV source:

```text
scripts/powershell/employees.csv
```

The account definitions are processed by:

```text
scripts/powershell/Import-BankingUsers.ps1
```

The provisioning process establishes:

- SAM account name
- User Principal Name
- Given name
- Surname
- Display name
- Initial password
- Account type
- Target OU
- Enabled state
- Security attributes
- Primary RBAC group membership

The provisioning process is automated through PowerShell using the Active Directory module.

### 3. Account Classification

Accounts are classified according to their operational purpose.

| Account Type | Purpose | Administrative Boundary |
| --- | --- | --- |
| Privileged | Elevated administrative operations | Tier 0, Tier 1 or Tier 2 |
| Standard | Normal workforce activity | Tier 2 |
| Service | Application, infrastructure or monitoring functions | Dedicated service identity boundary |

Account classification determines the appropriate OU, RBAC group and security controls.
The detailed account model is documented in:

```text
configuration/user-account-model.md
```

### 4. Access Assignment

Access is assigned through Global Security Groups rather than direct user-to-resource permissions.
The RBAC model associates identities with defined administrative or business roles.

Examples include:

```text
adm.jc.olfato
        |
        +-- GG-T0-AD-Administrators

adm.syd.srv01
        |
        +-- GG-T1-Server-Administrators

emily.taylor
        |
        +-- GG-Department-Finance
```

This approach provides a consistent separation between identity objects and resource permissions.

Changes to a user's role can therefore be managed through group membership without directly modifying individual resource ACLs.

### 5. Active Identity

Once provisioned and assigned the required access, an identity enters the active lifecycle state.
Active accounts must:

- Remain associated with a defined business or operational purpose
- Maintain appropriate RBAC membership
- Remain within the correct OU
- Comply with applicable account security controls
- Be subject to appropriate access review

Privileged and service identities require particular attention because their compromise may provide elevated or persistent access.

### 6. Role or Department Change

Identity attributes and access assignments may require modification when an employee changes role, department or administrative responsibility.
A role change should trigger review of:

- Department membership
- RBAC group membership
- Administrative tier
- OU placement
- Privileged access
- Account security attributes
  
Access associated with the previous role should be removed when it is no longer required.
The intended lifecycle is:

```text
Previous Role
     |
     v
Access Review
     |
     +---- Remove obsolete access
     |
     +---- Assign new role
     |
     v
Updated Identity
```

This prevents accumulation of unnecessary privileges over time.

### 7. Privileged Identity Management

Privileged identities are maintained separately from standard workforce accounts.

The implementation separates privileged accounts across administrative tiers:

| Tier | Identity Function | Example |
| --- | --- | --- |
| Tier 0 | Identity infrastructure administration | `adm.jc.olfato` |
| Tier 1 | Server infrastructure administration | `adm.syd.srv01` |
| Tier 2 | User computing / desktop support | `adm.syd.help01` |

Administrative identities use the `adm.` naming convention and are placed into dedicated administrative OUs.
Privileged accounts are also configured with:

```text
AccountNotDelegated = True
```

This provides an additional control against inappropriate credential delegation.

### 8. Service Identity Management

Service accounts represent non-human identities used by applications, infrastructure and monitoring services.
The implementation places service identities within:

```text
OU=Service_Accounts,DC=banking,DC=lab
```

Service accounts use the svc- naming convention.
Examples:

```text
svc-sql-banking
svc-sentinel-log
svc-app-portal
```

The current implementation applies:

- `PasswordNeverExpires = True`
- `CannotChangePassword = True`
- `AccountNotDelegated = True`
- Accidental deletion protection

Interactive logon restrictions are deferred to the Group Policy implementation stage.
In a production environment, service identities should additionally be evaluated for managed service accounts, privileged access management and centralised secrets management.

### 9. Identity Review

Identity reviews provide a mechanism for determining whether existing access remains appropriate.
A review should consider:

- Account status
- Account owner
- Department
- Current role
- RBAC membership
- Administrative tier
- OU placement
- Privileged access
- Service-account purpose
- Last authentication activity
- Dormant or unused accounts

The review objective is to identify:

- Excessive access
- Unauthorised group membership
- Dormant accounts
- Orphaned identities
- Incorrect OU placement
- Inappropriate privileged access
- Unnecessary service accounts

Periodic access reviews are a governance control and are separate from the initial provisioning process.

### 10. Account Suspension

Accounts that no longer require active access should be disabled before deletion.
Suspension may be required for:

- Employment termination
- Extended leave
- Security investigation
- Loss of business requirement
- Suspected account compromise
- Temporary access removal

The preferred sequence is:

```text
Active Account
      |
      v
 Disable Account
      |
      v
 Remove Access
      |
      v
 Review / Retain
      |
      v
 Deprovision
```

Disabling an account provides a reversible control while allowing the organisation to retain the identity object for investigation, audit or legal requirements where appropriate.

### 11. Deprovisioning

Deprovisioning removes access associated with an identity that no longer has a legitimate business requirement.
The process should include:

1. Disable the account.
2. Remove unnecessary RBAC group membership.
3. Revoke active access.
4. Review associated resources.
5. Identify ownership of files, applications or services.
6. Retain the identity object where required for audit or investigation.
7. Delete the account when retention requirements have been satisfied.

Deprovisioning should be controlled to prevent accidental removal of identities that remain operationally required.

### 12. Identity Deletion

Identity deletion represents the final lifecycle state.
Deletion should occur only after:

- Account disablement
- Access removal
- Ownership review
- Retention requirements have been considered
- Security or audit requirements have been satisfied

For service identities, deletion must also account for applications, scheduled tasks, services and dependencies that may still reference the account.

---

## Idempotent Provisioning

The provisioning process is designed to be safely re-executed.
The PowerShell provisioning script detects existing identities by SamAccountName.
Expected behaviour:

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

The provisioning implementation was successfully executed a second time after the initial account deployment.
All 10 existing identities were detected and skipped, and validation completed with zero failures.
This demonstrates repeatable provisioning without duplicate account creation.

---

## Identity Security Controls

The lifecycle model applies security controls according to identity type.

| Control | Privileged | Standard | Service |
| --- | --- | --- | --- |
| Dedicated account type | Yes | Yes | Yes |
| Dedicated OU placement | Yes | Yes | Yes |
| RBAC assignment | Yes | Yes | Yes |
| AccountNotDelegated | Yes | No | Yes |
| PasswordNeverExpires | No | No | Yes |
| CannotChangePassword | No | No | Yes |
| Accidental deletion protection | Yes | Yes | Yes |
| Interactive logon restriction | Deferred to GPO | N/A | Deferred to GPO |

The controls are intentionally differentiated according to the role and risk profile of each identity type.

---

### Audit and Evidence

Identity lifecycle activities should produce sufficient evidence to support administrative review and audit.
The current implementation maintains evidence through:

```text
evidence/user-provisioning-log.md
```

and supporting screenshots under:

```text
screenshots/active-directory-users/
screenshots/powershell/
screenshots/validation/
```

Evidence includes:

- Account provisioning output
- Idempotency results
- Account validation
- RBAC membership validation
- Active Directory account placement
- Account security attributes

Sensitive credentials and initial passwords are excluded from repository evidence.

---

## Automation and Repeatability

The identity lifecycle implementation separates account definitions from provisioning logic.
The architecture follows:

```text
employees.csv
      |
      v
Import-BankingUsers.ps1
      |
      v
Active Directory
      |
      +---- OU Placement
      |
      +---- Account Creation
      |
      +---- Security Attributes
      |
      +---- RBAC Assignment
      |
      v
Validation
```

This separation provides:

- Repeatable provisioning
- Consistent account creation
- Reduced manual configuration
- Easier validation
- Controlled changes to the identity population
- Improved auditability

---

## Deferred Lifecycle Controls

The current laboratory implementation establishes the foundational identity lifecycle model.
The following capabilities are intentionally deferred to subsequent implementation stages:

- Group Policy-based interactive logon restrictions
- Automated joiner/mover/leaver workflows
- Privileged access management
- Automated credential rotation
- Managed service account deployment
- Centralised secrets management
- Automated periodic access reviews
- Dormant account detection
- SIEM-based identity monitoring
- Automated deprovisioning workflows
These controls represent the next layer of enterprise IAM maturity rather than requirements for the foundational account provisioning implementation.

---

## Security Design Principles

The identity lifecycle model follows the following principles.

### Least Privilege

Identities receive only the access required for their defined role.

### Separation of Duties

Privileged responsibilities are separated across administrative tiers and security groups.

### Identity Accountability

Each human and service identity has a defined purpose and account classification.

### Lifecycle Governance

Identity access is expected to change as business roles and operational requirements change.

### Defence in Depth

OU separation, RBAC, account security attributes and policy enforcement provide complementary security controls.

### Repeatability

Automated provisioning ensures that defined account populations can be consistently deployed.

### Auditability

Provisioning and validation activities are documented through structured evidence.

---

## Implementation Status

| Capability | Status |
| --- | --- |
| Identity classification model | Complete |
| Declarative account definition | Complete |
| Automated account provisioning | Complete |
| OU-based identity placement | Complete |
| RBAC assignment | Complete |
| Privileged identity separation | Complete |
| Service identity separation | Complete |
| Account security controls | Complete |
| Idempotent provisioning | Complete |
| Independent account validation | Complete |
| Identity modification model | Defined |
| Access review model | Defined |
| Account suspension model | Defined |
| Deprovisioning model | Defined |
| Identity deletion model | Defined |
| Automated joiner/mover/leaver workflow | Deferred |
| Group Policy-based interactive logon restrictions | Deferred |
| Privileged access management | Deferred |
| Automated credential rotation | Deferred |
| Managed service account deployment | Deferred |
| Centralised secrets management | Deferred |
| Automated periodic access reviews | Deferred |
| Dormant account detection | Deferred |
| SIEM-based identity monitoring | Deferred |
| Automated deprovisioning workflows | Deferred |
