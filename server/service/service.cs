using System.Threading.Tasks;
using Apigee;
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
            var agent = msgCtxt.Request.headers.get("user-agent");
            _logger.LogInformation($"> ProcessMessage user-agent: {agent}");
            msgCtxt.Request.headers.put("x-added", DateTime.UtcNow.ToString("o"));
            return Task.FromResult(msgCtxt);
        }
    }
}
