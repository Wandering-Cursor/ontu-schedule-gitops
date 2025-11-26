# Sealed Secrets Controller Helm Chart

This chart installs the Sealed Secrets controller, which allows you to encrypt secrets that can be safely stored in Git.

## Installation

```bash
helm install sealed-secrets . -n kube-system
```

## What is Sealed Secrets?

Sealed Secrets provides a way to encrypt Kubernetes secrets so they can be safely stored in version control. The controller runs in your cluster and decrypts sealed secrets into regular secrets.

## Fetching the Public Key

After installation, get the public key for sealing secrets:

```bash
kubeseal --fetch-cert > pub-cert.pem
```

## Configuration

See `values.yaml` for available configuration options.
