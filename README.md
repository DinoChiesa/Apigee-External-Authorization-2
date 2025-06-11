# Apigee External Access Control example

This repository shows one way to include externally-driven access
control decisions into Apigee API proxies.

It is possible to include _basic_ access control into Apigee, using the Apigee configuation flow
language.  But to include more dynamic access control into an Apigee API proxy, often you will
want to _externalize_ the access control decision, and allow Apigee to enforce the decision.

This repository shows one way to do that, using an implementation involving:
- An API Proxy configured in Apigee X (cloud)
- a Cloud Run service that makes access control decisions
- an ExternalCallout policy in the Apigee proxy to call to the Cloud Run service


## Background

_Basic_ access control in Apigee, using the Apigee configuation flow language, is easy.  For
example, it's really easy to configure an Apigee API proxy to allow access, only if the caller
presents a valid token (using the built-in Apigee policy
[`OAuthV2`](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oauthv2-policy),
with Operation = `VerifyAccessToken`).  Or a valid, unexpired API Key (using the built-in Apigee
policy
[`VerifyAPIKey`](https://cloud.google.com/apigee/docs/api-platform/reference/policies/verify-api-key-policy)).

In the simple case, the OAuthV2/VerifyAccessToken policy would look like this:
```xml
<OAuthV2 name="OAuthV2-Verify-Access-Token">
  <Operation>VerifyAccessToken</Operation>
</OAuthV2>
```

And the VerifyAPIKey policy would look like this:
```xml
<VerifyAPIKey name="APIKeyVerifier">
  <APIKey ref="request.queryparam.apikey" />
</VerifyAPIKey>
```

In the former case, the one relying on the OAuthV2 access token, of course, the calling app must
have previously obtained the access token, via some grant flow. That is just the standard
OAuthV2 model, nothing new there.

But as you can see, whether using a key or a token, the control is binary. Either the caller has
the valid key or token, or it does not. Well it's not quite so simple: Apigee has the API product concept,
which means that API publishers can configure specific client credentials (client IDs or API keys)
to be authorized for specific API Products.  The Products are really just collections of
Verb + Path pairs which will be permitted.  Then, at runtime, Apigee will verify that the presented application client credential
must be authorized for an API Product that includes the
particular verb + path pair that the current API request is using.

At configuration time:
- API publishers define API Products. Each one includes 1 or more verb + path pairs.
- Client developers obtain credentials (client IDs) for their apps. Each credential is authorized for one or more API Products.
- Client developers embed those credentials into the apps they build.

At runtime:
- client app sends in GET /foo (verb = GET, path = /foo)
- Apigee checks the key or token, depending on the policy you attach to your API Proxy
- if valid, Apigee checks that the verb + path pair is authorized via at least one of the API Products

And beyond the basics, you can also configure Apigee to check a scope on an Access Token.

This is all very powerful, and allows API Platform teams to control which apps can call which APIs.
To repeat: this controls which applications can call.

One thing that is missing here is "role based access control", a/k/a RBAC, which would allow an
access control decision based on the _identity of the human_ operating the application.

Apigee does not have a good mechanism, by itself, for performing user-by-user RBAC.

The typical pattern is to _externalize_ the access control decision and use Apigee to _enforce_ the decision.

This means, while handling an inbound API call, Apigee can
- send an access control request to an external Access Control system
- get the response (Allow or Deny)
- enforce that decision

The example contained in this repository shows how you can implement this using
a custom Cloud Run service to externalize the access control decision.

## Disclaimer

This example is not an official Google product, nor is it part of an
official Google product.

## Support

This callout is open-source software, and is not a supported part of Apigee.  If
you need assistance, you can try inquiring on [the Google Cloud Community forum
dedicated to Apigee](https://goo.gle/apigee-community) There is no service-level
guarantee for responses to inquiries posted to that site.

## License

This material is [Copyright © 2025 Google LLC](./NOTICE).
and is licensed under the [Apache 2.0 License](LICENSE). This includes the Java
code as well as the API Proxy configuration.

## Bugs

* ??
