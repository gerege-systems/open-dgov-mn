# Overview

*A summary of the Mongolian documentation rather than a mirror of it. Where
the two disagree, [the Mongolian pages](index.md) are the source.*

Two domains, one system:

| | What it is | Address |
| --- | --- | --- |
| **Open foundation platform** | The base that government bodies build their own services on | [open.dgov.mn](https://open.dgov.mn) |
| **Unified government sign-in** | The one place that decides who someone is | [sso.dgov.mn](https://sso.dgov.mn) |

The relationship runs one way: the platform no longer identifies anyone
itself, and delegates that to the sign-in service. So there is one answer to
"where is this person signed in", and one place to revoke it.

## Why a foundation platform

Every government system otherwise writes its own sign-in, its own permission
model, its own audit trail and its own translations. None of that is specific
to the system — they are versions of the same thing, each written slightly
differently and each broken slightly differently. When one of them fails, the
others do not hear about it.

A foundation platform means not writing those again:

- **One identity.** eID, DAN and passwords all resolve into one session model.
- **One permission model.** Organisations, memberships, roles and permissions.
  Every query is bounded by organisation, and application code does not have
  to remember that.
- **One audit trail.** Who changed what and when, from the first day.
- **One set of languages.** Mongolian as the source plus the six official UN
  languages; CI fails on a missing translation, so a half-translated screen
  cannot ship.
- **One resilience layer.** Circuit breaking, load shedding, request
  coalescing and backoff retries belong to the platform rather than to each
  service.

None of it is an add-on. It sits in the core, so everything built on top
inherits it.

## Architecture

A modular monolith: each module owns its domain, its migrations and its
permissions, and they all compile into a single Go binary. A call between two
modules is a function call, not a network hop — the organisation of a
distributed system without its latency or its debugging.

Tenancy is enforced in the database with row-level security rather than by
application discipline. An app that a given organisation has not installed
refuses the request: the code is there, the door is not open.

## Signing in

`sso.dgov.mn` is a standard OpenID Connect provider — `authorization_code`
with PKCE, RS256 tokens, discovery at
`/.well-known/openid-configuration`. Any OIDC client library will work; there
is no special protocol and no SDK to adopt.

Beyond authentication it owns active sessions (with remote revocation), access
review campaigns, one-way SCIM 2.0 provisioning, and a per-organisation
register of trusted external identity providers.

See [Connecting a system](federation.md) for how to register a client.

## Open source

Built on [Gerege Nexus](https://github.com/gerege-systems/open-gerege-nexus),
Apache 2.0. This deployment is open too:
[open-dgov-mn](https://github.com/gerege-systems/open-dgov-mn),
[sso-dgov-mn](https://github.com/gerege-systems/sso-dgov-mn).
