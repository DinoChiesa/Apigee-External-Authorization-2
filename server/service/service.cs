using System;
using System.Linq;
using System.Threading.Tasks;
using Apigee.ExternalCallout;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Server
{
    public class DinoCalloutService : ExternalCalloutService.ExternalCalloutServiceBase
    {
        private readonly ILogger _logger;

        public DinoCalloutService(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<DinoCalloutService>();
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
