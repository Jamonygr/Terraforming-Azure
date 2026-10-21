# Security

Do not open a public issue containing tokens, state files, plans, passwords,
private keys, subscription inventories, or personal data. Use GitHub private
vulnerability reporting when available. Revoke exposed credentials immediately.

These are short-lived learning deployments. Inspect plans and verify your explicit
subscription ID before applying. WAF, Firewall, Bastion and VPN provide different
boundaries; the course does not claim that every packet follows the Firewall.
Terraform state and plans can contain sensitive values even when outputs are marked
`sensitive`. Backend access is privileged operational access.
