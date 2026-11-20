# Security

## Reporting a vulnerability

If you find a security problem in the scripts or docs in this repository, please
report it privately rather than opening a public issue.

- GitHub private vulnerability reporting: use **Security → Report a vulnerability**
  on this repository, if it is enabled.
- Otherwise, open an issue that says only *"security report, please contact me"*
  with no detail, and I will follow up privately.

Please include a description, the affected file, and steps to reproduce if you have
them.

## Things that are deliberately not in this repository

This repo is **documentation and scripts only**. It contains no credentials, no
device images, no firmware, and no keys.

Specifically excluded:

| Excluded | Why | Where it belongs instead |
|---|---|---|
| NAS account passwords | Machine-specific secret | A `config.json` with mode `0600`, gitignored |
| Bridge / relay tokens | Machine-specific secret | An environment variable or a local secrets file |
| Android release keystores and `keystore.properties` | Signing key | Your own keystore, never committed |
| ADB private keys | Grants shell access to the device | `~/.android/adbkey` |
| `device.pit` and firmware archives | Large, and device-specific | Dumped on demand from your own device |

`.gitignore` blocks the common accident (`config.json`, `*.jks`, `keystore.properties`,
`*.log`, `*.zip`, `*.img`). If you add a file type that could hold a secret, add it
to `.gitignore` in the same pull request.

## If you have already committed a secret

Removing a file from a later commit does not remove it from history. If you commit a
credential by accident:

1. **Rotate the credential first.** That is the only step that actually fixes it.
   Assume anything pushed to a public repository has been read by an automated
   scraper within minutes.
2. Then rewrite history (`git filter-repo`, or `BFG`) and force-push.
3. Open a pull request noting the rotation if the repository is a fork with
   contributors.

Rotating first, cleaning second. The reverse order leaves you exposed for longer
than necessary.

## A note on trust

The scripts in `scripts/` talk to a device over USB and can write to its
partitions. Read them before running them. They are written to be cautious — they
confirm before anything irreversible and they refuse to pipe device output — but you
are the one holding the phone, and reading the script is your last line of defence.
