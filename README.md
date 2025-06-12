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
the valid key or token, or it does not.

### The use of API Products for Access Control

Well it's not quite so simple: Apigee has the API product concept,
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

There is a handy
[working sample](https://github.com/GoogleCloudPlatform/apigee-samples/tree/main/apiproduct-operations)
that walks you through this, actually working in Apigee. Check it out!

### What about more flexible controls?

This is all very powerful, and allows API Platform teams to control which _apps can call which
APIs_.  One thing that is missing here is "role based access control", a/k/a RBAC, which would
allow an access control decision based on the _identity of the human_ operating the
application. Also missing is ABAC, what [OWASP calls "Attribute Based Access
Control"](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html#prefer-attribute-and-relationship-based-access-control-over-rbac),
which allows control based not just on the role or identity of the caller, but also based on additional
data, such as: Job role, time of day, project name, MAC address, record creation date, prior activity pattern, and
others. Apigee does not have a good mechanism, by itself, for performing either user-by-user RBAC or the more advanced ABAC.

To accomplish user-based RBAC, or the more general ABAC, the typical pattern is to _externalize_
the access control decision and use Apigee to _enforce_ the decision.

The way it works for handling an inbound API call:

- Apigee sends an access control request to an external Access Control system. This request must include
  all the metadata that the external system will need to make a decision. The identity of the
  caller, the resource being requested, the specific action being requested, the source IP
  address, and so on. Whatever is required.

- The external system makes the decision (Allow or Deny), and sends it back to Apigee.

- The Apigee API proxy then enforces that decision.

The example contained in this repository shows how you can implement this pattern using
a custom Cloud Run service to externalize the access control decision.

## Disclaimer

This example is not an official Google product, nor is it part of an
official Google product.


## Implementation Details

Here's how it works.

 1. An app sends an API request into an Apigee API proxy.
 2. The Apigee API proxy calls to an external Service implemented in C#, passing it {subject, resource, action}
 3. C# service calls to Google Sheets to retrieve rules and roles
 4. C# service applies the access rules and returns a "ALLOW" or "DENY" to the proxy
 5. The proxy enforces that decision.

This particular implementation example uses a Google Sheet to store access control rules, and
some custom logic coded in C# to apply those rules.

The rules look like this:
![Screenshot](./images/Screenshot-20250611-183553.png)

And the logic that evaluates whether a request should be authorized according to those rules
looks like this:

```csharp
  private async Task<Boolean> EvaluateAccess(string subject, string resource, string action)
  {
      GsheetData rules = await _rds.GetAccessControlRules();
      GsheetData roles = await _rds.GetRoles();
      String role = ResolveRole(roles, subject);

      if (rules?.Values != null)
      {
          // First pass: check for specific role match
          if (role != null)
          {
              foreach (var ruleEntry in rules.Values)
              {
                  bool? allowed = CheckRule(ruleEntry, role, resource, action );
                  if (allowed.HasValue)
                      return allowed.Value;
              }
          }

          // Second pass: fallback to "any" role match
          foreach (var ruleEntry in rules.Values)
          {
              bool? allowed = CheckRule( ruleEntry, "any", resource, action );
              if (allowed.HasValue)
                  return allowed.Value;
          }
      }
      return false;
  }
```

### Why not OPA for this?

_Gooood Question!!_ [Open Policy Agent](https://www.openpolicyagent.org/) is a good solution for
storing, managing, and evaluating access rules.  It's open source, well maintanied, and
available as a deployable container image. You can deploy it right to something like Cloud Run;
no need to build the code.

All sounds good, right?  The _one drawback_ that I've seen is that OPA depends on
[REGO](https://www.openpolicyagent.org/docs/policy-language) to express policies. This is
a domain-specific language; I have not seen it used in any place _other_ than OPA.
That can be an obstacle to some teams.

I wanted to use a Google Sheet to store the access rules because it's visual - it's easy to see what
specific rules are in place; it's easy to demonstrate; and it's easy to update and maintain the
access rules.  It's easy to _protect_ the access rules with User rights on the Sheets document.
The C# logic that applies the rules is also fairly easy to understand. The combination of all of
those factors means using Sheets and C# makes for a solution that is more broadly _accessible_
than one based on the combination of OPA and REGO.

BUT, the architectural model of the solution using OPA would be _exactly the same_ as what I've
got here with C# and a Google Sheet.


## Screencast

TO BE ADDED

## Deploying it for your own purposes

To follow the instructions to deploy this in your own, you will need the following pre-requisites:

- Apigee X or hybrid
- a Google Cloud project with Cloud Run enabled
- a Google Workspace environment that allows you to create and share spreadsheets
- .NET 8.0
- various tools: bash, gcloud, apigeecli, jq


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

* The Cloud Run service is deployed to allow "unauthenticated access".
* The C# service does not check for malformed rules or roles.
* ??

