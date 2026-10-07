# IAM — Governance

AWS Identity and Access Management controls authentication and authorization. Users represent long-lived human/service identities, groups collect users, and roles provide assumable temporary credentials. Policies are JSON permission documents evaluated from identity, resource, boundary, organization, and session policies; an explicit deny wins.

Apply least privilege, prefer federation and roles over access keys, require MFA, rotate/remove unused credentials, constrain trust policies, review with Access Analyzer, log with CloudTrail, and separate workloads/accounts. Common uses include employee federation, EC2 workload roles, cross-account access, CI/CD deployment roles, and service-control guardrails.
