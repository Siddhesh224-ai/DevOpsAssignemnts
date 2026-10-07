# VPC — Networking

A VPC is an isolated virtual network defined by CIDR ranges. Subnets occupy availability zones. Route tables decide the next hop; an Internet Gateway supports public internet routing, while a NAT Gateway lets private-subnet resources initiate outbound IPv4 connections.

Security groups are stateful resource firewalls; network ACLs are stateless subnet filters. A public subnet has a route to an Internet Gateway and its workload still needs a public address and permissive policy. A private subnet has no direct inbound internet route. Typical designs distribute public load balancers and private applications/databases across multiple availability zones.
