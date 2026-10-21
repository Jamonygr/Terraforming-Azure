# Live Azure smoke matrix

This matrix is a maintainer runbook. Blank/unexecuted rows are not passed tests.
Static validation and mocked plans do not contact Azure. Use a disposable,
explicit subscription and a dated regional price worksheet before running paid
stages. Record commit, Terraform/AzureRM versions, region and execution time.

| Stage / area | Probe | Required evidence |
|---|---|---|
| Every deployment | Second normal plan | Exit code 0 with no changes |
| Foundation | VNet/subnet/peering inventory | Correct non-overlapping prefixes and connected peers |
| Secure | Firewall/Bastion/resolver | Healthy provisioning, expected IPs, final DNS settings |
| Applications | HTTPS to WAF | HTTP200 with backend identity |
| Applications | WAF test header | HTTP403 and matching diagnostic record |
| Applications | Backend health | Both IIS targets healthy |
| Administration | Bastion to Windows | Private RDP session; no VM public IP |
| Egress | Allowed and denied FQDN | Contrasting results plus matching Firewall logs |
| Interspoke | Approved and forbidden flow | Effective next hops plus allow/deny evidence |
| Private services | Resolve original service FQDN | Private endpoint address from Azure source |
| Identity | Read designated sample data | Allowed workload MI succeeds; unauthorized principal denied |
| Hybrid | VPN status/counters | Both connections connected and carrying traffic |
| Hybrid | Azure to corporate DNS | Expected corporate record over resolver outbound path |
| Hybrid | Corporate to Azure private DNS | Private Blob/Key Vault answers and reachable authorized service |
| Monitoring | Queries and alert exercise | Diagnostic/guest records and expected alert state |
| Recovery | Deliberate DNS/route/policy failure | Failure reproduced, cause identified, repair verified |
| Cleanup | Resource inventory and group existence | Capstone removed, backend intentionally retained |
| Backend teardown | Local migration then destroy | State migrated and backend resource group absent |

Use retries with a bounded deadline for DNS/RBAC propagation and telemetry
arrival. Distinguish eventual consistency from an incorrect configuration. Save
evidence outside Git, sanitize output before sharing, and record failures rather
than checking boxes based on successful `terraform apply` alone.
