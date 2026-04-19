Add OpenID Connect to kirby and yoshi services

Status: see [auth-oidc](../auth-oidc.md)

Goals:
- Start with one or two services for proof of concept
- Able to support most services
- Ideally single sign on across services, but shared login credentials are more important
- Should be redundant, able to work when either yoshi or kirby are offline
- LDAP in case some services need it - either exposed as an interface, or a separate LDAP backend
