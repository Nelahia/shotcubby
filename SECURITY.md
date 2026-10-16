# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub:
**[Report a vulnerability](https://github.com/Nelahia/shotcubby/security/advisories/new)**
(repository → Security → *Report a vulnerability*).

Include what you found, how to reproduce it, and the version (it is shown in
Settings). ShotCubby is maintained by one person in their spare time, so replies
are best-effort and there is no guaranteed response time. There is no bug bounty.

## Supported versions

Only the [latest release](https://github.com/Nelahia/shotcubby/releases/latest)
receives fixes. Both apps update themselves (Windows automatically, macOS through
*Check for Updates…*), so please update before reporting.

## Scope

ShotCubby works on your machine and collects nothing. The optional AI naming
feature, off by default, sends a downscaled copy of each new screenshot to the AI
provider you chose, using your own API key, which is stored in the OS keychain and
never in ShotCubby's settings files. The things worth reporting
are, for example: a way to make the apps open, read or delete files outside the
screenshot folders, a flaw in how updates are downloaded or verified, or a problem
in the release workflow that could ship a tampered build.

## No warranty

ShotCubby is provided **as is, without warranty of any kind**, under the
[MIT License](LICENSE). Use it at your own risk. This policy describes how
problems are handled; it is not a guarantee that the software is free of them.
