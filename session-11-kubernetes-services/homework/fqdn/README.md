# Kubernetes FQDN

An FQDN is a complete, unambiguous DNS name. A normal Kubernetes Service resolves as:

```text
<service>.<namespace>.svc.<cluster-domain>
```

For the default cluster domain, examples are `api.default.svc.cluster.local` and `database.production.svc.cluster.local`. A Pod in the same namespace can normally use only the Service name. Cross-namespace calls should use at least `service.namespace`; the full FQDN removes search-path ambiguity. A Pod reaches a Service by resolving its DNS name to the ClusterIP and connecting to the Service port. Headless Service DNS instead returns endpoint/Pod addresses.
