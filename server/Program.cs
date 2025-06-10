using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Server;

namespace ExternalCalloutDemo
{
    public static class Program
    {
        private const String SERVICE_NAME = "external-callout-demo-service";

        public static void Main(string[] args)
        {
            try
            {
                var builder = WebApplication.CreateBuilder(args);
                builder.Services.AddGrpc();
                builder.Services.AddMemoryCache();
                builder.Services.AddHttpClient();

                var app = builder.Build();
                app.MapGrpcService<AccessControlService>();

                Console.Error.WriteLine($"{SERVICE_NAME} Starting up...");
                String buildTime = cmdwtf.BuildTimestamp.BuildTimeUtc.ToString(
                    "o",
                    System.Globalization.CultureInfo.InvariantCulture
                );
                Console.Error.WriteLine($"Build time: {buildTime}");

                // Disable QUIC / H3 - it is not currently permitted in Cloud Run.
                //
                // .NET 8 and .NET 9 has HTTP/3 enabled as a
                // default whereas Cloud Run supports HTTP/1 or HTTP/2 only.
                //
                // refer to: https://github.com/dotnet/runtime/issues/94794
                AppContext.SetSwitch("System.Net.SocketsHttpHandler.Http3Support", false);

                // Cloud Run will provide a PORT in the environment, which this service must use
                var port = Environment.GetEnvironmentVariable("PORT") ?? "9090";
                var url = $"http://0.0.0.0:{port}";
                app.Run(url);
            }
            catch (Exception e)
            {
                Console.Error.WriteLine(e.ToString());
            }
        }
    }
}
