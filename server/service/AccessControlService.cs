// Copyright © 2025 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

using System;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Apigee.ExternalCallout;
using Grpc.Core;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace Server
{
    public class AccessControlService : ExternalCalloutService.ExternalCalloutServiceBase
    {
        private readonly ILogger _logger;
        private readonly IMemoryCache _memoryCache;

        //private readonly IHttpClientFactory _httpClientFactory;
        private readonly RemoteDataService _rds;

        public AccessControlService(
            ILoggerFactory loggerFactory,
            IMemoryCache memoryCache,
            IHttpClientFactory httpClientFactory
        )
        {
            _logger = loggerFactory.CreateLogger<AccessControlService>();
            _memoryCache = memoryCache;
            _rds = new RemoteDataService(_memoryCache, httpClientFactory);
            //_httpClientFactory = httpClientFactory;
        }

        private String ResolveRole(GsheetData roles, String subject)
        {
            if (roles?.Values != null)
            {
                // First pass: check for exact matches
                foreach (var entry in roles.Values)
                {
                    if (entry != null && entry.Count >= 2)
                    {
                        string pattern = entry[0];
                        string role = entry[1];
                        if (pattern == subject)
                        {
                            _logger.LogInformation(
                                $"ResolveRole: Exact match for subject '{subject}' found role '{role}'."
                            );
                            return role;
                        }
                    }
                }

                // Second pass: check for domain matches
                foreach (var entry in roles.Values)
                {
                    if (entry != null && entry.Count >= 2)
                    {
                        string pattern = entry[0];
                        string role = entry[1];

                        if (pattern.StartsWith("*@"))
                        {
                            string domain = pattern.Substring(1); // Remove the '*'
                            // Escape the domain part for regex and construct the regex pattern
                            // e.g. *@foo.com -> [^@]+@foo\.com
                            string regexPattern = $"^[^@]+@{Regex.Escape(domain.Substring(1))}$";
                            if (
                                subject.Contains("@")
                                && Regex.IsMatch(subject, regexPattern, RegexOptions.IgnoreCase)
                            )
                            {
                                _logger.LogInformation(
                                    $"ResolveRole: Domain match for subject '{subject}' with pattern '{pattern}' found role '{role}'."
                                );
                                return role;
                            }
                        }
                    }
                }
            }
            _logger.LogInformation(
                $"ResolveRole: No specific role found for subject '{subject}'. Returning null."
            );
            return null;
        }

        private bool? CheckRule(
            System.Collections.Generic.List<string> ruleEntry,
            string targetRole,
            string resource,
            string action,
            string logContext
        )
        {
            if (ruleEntry != null && ruleEntry.Count >= 4)
            {
                // ruleEntry[0] = role, ruleEntry[1] = resource, ruleEntry[2] = action, ruleEntry[3] = permission
                if (
                    string.Equals(ruleEntry[0], targetRole, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(ruleEntry[1], resource, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(ruleEntry[2], action, StringComparison.OrdinalIgnoreCase)
                )
                {
                    _logger.LogInformation(
                        $"EvaluateAccess: {logContext}. Resource='{resource}', Action='{action}'. Rule='[{string.Join(", ", ruleEntry)}]'. Permission='{ruleEntry[3]}'."
                    );
                    return string.Equals(ruleEntry[3], "ALLOW", StringComparison.OrdinalIgnoreCase);
                }
            }
            return null; // No match for this rule
        }

        private async Task<Boolean> EvaluateAccess(string subject, string resource, string action)
        {
            GsheetData rules = await _rds.GetAccessControlRules();
            GsheetData roles = await _rds.GetRoles();
            String role = ResolveRole(roles, subject); // role can be null if not found

            if (rules?.Values != null)
            {
                // First pass: check for specific role match
                if (role != null)
                {
                    foreach (var ruleEntry in rules.Values)
                    {
                        bool? allowed = CheckRule(
                            ruleEntry,
                            role,
                            resource,
                            action,
                            $"Specific role match. Role='{role}'"
                        );
                        if (allowed.HasValue)
                            return allowed.Value;
                    }
                }

                // Second pass: fallback to "any" role match
                foreach (var ruleEntry in rules.Values)
                {
                    bool? allowed = CheckRule(
                        ruleEntry,
                        "any",
                        resource,
                        action,
                        "'any' role match"
                    );
                    if (allowed.HasValue)
                        return allowed.Value;
                }
            }

            _logger.LogInformation(
                $"EvaluateAccess: No matching rule found. Role='{role ?? "null"}', Resource='{resource}', Action='{action}'. Denying access."
            );
            return false;
        }

        public override async Task<MessageContext> ProcessMessage(
            MessageContext msgCtxt,
            ServerCallContext context
        )
        {
            _logger.LogInformation($"> ProcessMessage");

            if (msgCtxt.Request != null)
            {
                // Add or update header using the indexer
                msgCtxt.Request.Headers["x-added-by-extcallout"] = new Strings
                {
                    Strings_ = { DateTime.UtcNow.ToString("o") },
                };
            }

            var subject = msgCtxt.AdditionalFlowVariables["accesscontrol.subject"].String;
            var action = msgCtxt.Request.Verb;
            var resource = msgCtxt.Request.Uri;
            bool isAllowed = await EvaluateAccess(subject, resource, action);
            msgCtxt.AdditionalFlowVariables.Add("accesscontrol.result", new FlowVariable());
            msgCtxt.AdditionalFlowVariables["accesscontrol.result"].String = isAllowed
                ? "ALLOW"
                : "DENY";
            return msgCtxt;
        }
    }
}
