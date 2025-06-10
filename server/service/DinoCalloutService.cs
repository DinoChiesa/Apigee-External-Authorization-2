using System;
using System.Linq;
using System.Net.Http;
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

        private Task<Boolean> EvaluateAccess(string subject, string resource, string action)
        {
            return Task.FromResult(true);
        }

        public override async Task<MessageContext> ProcessMessage(
            MessageContext msgCtxt,
            ServerCallContext context
        )
        {
            _logger.LogInformation($"> ProcessMessage");
            AccessControlRules rules = await _rds.GetAccessControlRules();

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
