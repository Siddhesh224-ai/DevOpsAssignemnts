# CoreDNS

CoreDNS is the Kubernetes cluster DNS server. Kubelet configures Pods to query the `kube-dns` Service, and CoreDNS watches the Kubernetes API to synthesize Service and Pod records. Its Corefile controls plugins such as `kubernetes`, `forward`, `cache`, `health`, and `ready`.

Troubleshooting sequence:

1. Check `coredns` Pods and the `kube-dns` Service in `kube-system`.
2. Inspect CoreDNS logs and its ConfigMap/Corefile.
3. Run `nslookup kubernetes.default.svc.cluster.local` from a temporary Pod.
4. Confirm the target Service has ready EndpointSlices.
5. Inspect the Pod's `/etc/resolv.conf`, namespace, DNS policy, and any NetworkPolicies.

DNS resolution does not guarantee application connectivity: selectors, ready endpoints, ports, and network policy must also be correct.
