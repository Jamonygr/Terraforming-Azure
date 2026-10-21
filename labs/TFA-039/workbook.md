# Capstone design and readiness workbook

Complete this locally before starting TFA-040. Replace the proposed address plan with the exact plan you will apply in that lab; do not change the capstone merely to match these examples.

## Ownership and prerequisites

| Decision | Record your answer |
| --- | --- |
| Sandbox subscription and tenant | |
| Region and service/SKU availability | |
| VM vCPU and VPN/Firewall/WAF quota checked | |
| State backend resource group, account, container, and key | |
| Identity permitted to write state blobs | |
| Deployment identity and exact RBAC scopes | |
| Role-assignment permissions needed by the code | |
| Expected service deployment time | |
| Current calculator estimate and maximum deployment window | |
| Cleanup owner and date/time | |

## Network address plan

| Network | Proposed CIDR | Purpose |
| --- | --- | --- |
| Hub | 10.0.0.0/16 | Shared network services |
| Application spoke | 10.10.0.0/16 | Private IIS application |
| Data spoke | 10.20.0.0/16 | Private service endpoints |
| Operations spoke | 10.30.0.0/16 | Management/test workloads |
| Simulated site | 192.168.0.0/16 | Azure-hosted remote-site simulation |

Check both exact duplication and partial overlap. Reserve the required dedicated subnets and sizes from the actual capstone implementation. Record peering direction, forwarded-traffic flags, gateway-transit flags, and which route tables attach to which subnets. Explicitly explain why the Application Gateway subnet must not inherit a generic workload default route.

## Traffic and evidence matrix

| Flow | DNS answer | Forward path | Return path | Enforcement | Evidence |
| --- | --- | --- | --- | --- | --- |
| Internet HTTPS -> WAF -> private IIS | | | | | |
| Attack-shaped request -> WAF denial | | | | | |
| IIS/operations -> private service | | | | | |
| Spoke -> spoke through Firewall | | | | | |
| Spoke -> permitted internet destination | | | | | |
| Spoke -> denied destination | | | | | |
| Simulated site -> Azure private address | | | | | |
| Simulated DNS -> Azure private service name | | | | | |

Do not assume peering is transitive, that a default route beats a longer prefix, or that DNS resolution grants data-plane permission. Name one decisive failure test for each enforcement layer.

## State, stages, and recovery

Record the capstone's staged configuration inputs in order. Confirm every stage is cumulative, uses the same capstone state, and has a clean ordinary plan before advancing. Use the independent bootstrap state only for its backend resources. Describe how you resume a failed stage without routine targeting, protect secrets in state, bind reviewed workflow plans to the same commit, and recover a previous backend blob version if needed.

## Final acceptance and teardown

Record the normal HTTP response, both backend health states, WAF denial, Firewall allow/deny evidence, private service DNS/IP/TCP evidence, VPN Connected state and traffic, guest telemetry, and one controlled-fault repair. A successful apply is not final acceptance.

Destroy the full capstone before considering bootstrap removal. Record how lock removal, soft deletion, log retention, state backups, private backend reachability, and any subscription-scoped policy/role resources are handled. Describe which retained resources still cost money.
