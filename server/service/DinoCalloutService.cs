using System;
using System.Linq;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Apigee.ExternalCallout;
using Grpc.Core;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace Server
{
    public class DinoCalloutService : ExternalCalloutService.ExternalCalloutServiceBase
    {
        private readonly ILogger _logger;
        private readonly IMemoryCache _memoryCache;

        //private readonly IHttpClientFactory _httpClientFactory;
        private readonly RemoteDataService _rds;

        public DinoCalloutService(
            ILoggerFactory loggerFactory,
            IMemoryCache memoryCache,
            IHttpClientFactory httpClientFactory
        )
        {
            _logger = loggerFactory.CreateLogger<DinoCalloutService>();
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
                        if (ruleEntry != null && ruleEntry.Count >= 4)
                        {
                            // ruleEntry[0] = role, ruleEntry[1] = resource, ruleEntry[2] = action, ruleEntry[3] = permission
                            if (string.Equals(ruleEntry[0], role, StringComparison.OrdinalIgnoreCase) &&
                                string.Equals(ruleEntry[1], resource, StringComparison.OrdinalIgnoreCase) &&
                                string.Equals(ruleEntry[2], action, StringComparison.OrdinalIgnoreCase))
                            {
                                _logger.LogInformation($"EvaluateAccess: Specific role match. Role='{role}', Resource='{resource}', Action='{action}'. Rule='[{string.Join(", ", ruleEntry)}]'. Permission='{ruleEntry[3]}'.");
                                return string.Equals(ruleEntry[3], "ALLOW", StringComparison.OrdinalIgnoreCase);
                            }
                        }
                    }
                }

                // Second pass: fallback to "any" role match
                foreach (var ruleEntry in rules.Values)
                {
                    if (ruleEntry != null && ruleEntry.Count >= 4)
                    {
                        // ruleEntry[0] = role, ruleEntry[1] = resource, ruleEntry[2] = action, ruleEntry[3] = permission
                        if (string.Equals(ruleEntry[0], "any", StringComparison.OrdinalIgnoreCase) &&
                            string.Equals(ruleEntry[1], resource, StringComparison.OrdinalIgnoreCase) &&
                            string.Equals(ruleEntry[2], action, StringComparison.OrdinalIgnoreCase))
                        {
                            _logger.LogInformation($"EvaluateAccess: 'any' role match. Resource='{resource}', Action='{action}'. Rule='[{string.Join(", ", ruleEntry)}]'. Permission='{ruleEntry[3]}'.");
                            return string.Equals(ruleEntry[3], "ALLOW", StringComparison.OrdinalIgnoreCase);
                        }
                    }
                }
            }

            _logger.LogInformation($"EvaluateAccess: No matching rule found. Role='{role ?? "null"}', Resource='{resource}', Action='{action}'. Denying access.");
            return false; // Default to false (deny) if no rule is matched
        }

        public override Task<MessageContext> ProcessMessage(
            MessageContext msgCtxt,
            ServerCallContext context
        )
        {
            _logger.LogInformation($"> ProcessMessage");

            string agent = null;
            // Access headers using the correct property name 'Headers' and appropriate methods
            if (
                msgCtxt.Request != null
                && msgCtxt.Request.Headers.TryGetValue("user-agent", out var userAgentStrings)
            )
            {
                agent = userAgentStrings.Strings_.FirstOrDefault();
            }
            _logger.LogInformation($"> ProcessMessage user-agent: {agent}");

            if (msgCtxt.Request != null)
            {
                // Add or update header using the indexer
                msgCtxt.Request.Headers["x-added-by-extcallout"] = new Strings
                {
                    Strings_ = { DateTime.UtcNow.ToString("o") },
                };
            }
            return Task.FromResult(msgCtxt);
        }
    }
}
