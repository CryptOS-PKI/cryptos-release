# Release manifest

`release.yaml` pins the components that make up one CryptOS release, so a release can be installed and verified as a set.

| Key | What it pins |
|---|---|
| `version` | The release version. `v0.1.0-dev` until the first release. |
| `node` | The node OS image from [`cryptos-node`](https://github.com/CryptOS-PKI/cryptos-node): the release asset or image reference in `image`. |
| `manager` | The Fleet Manager container image from [`cryptos-manager`](https://github.com/CryptOS-PKI/cryptos-manager), by `digest`. |
| `web` | The [`cryptos-web`](https://github.com/CryptOS-PKI/cryptos-web) console. `bundled: true` means it ships inside the manager image, so the manager digest pins it. |

The `null` values are placeholders. They're filled in when a release is cut, from the published node release asset and the manager image digest, and the manifest is committed with that release.
