using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;

namespace Server
{
    public class RemoteDataService
    {
        private readonly IMemoryCache _memoryCache;
        private readonly IHttpClientFactory _httpClientFactory;

        // the following should be either in an appSettings.json file or from environment
        private readonly string PROJECT_ID;
        private readonly string SERVICE_ACCOUNT;
        private readonly string SHEET_ID;
        private const string ACL_RANGE = "Rules!A2:D102";
        private const string ROLES_RANGE = "Roles!A2:B102";

        public RemoteDataService(IMemoryCache memoryCache, IHttpClientFactory httpClientFactory)
        {
            _memoryCache = memoryCache;
            _httpClientFactory = httpClientFactory;
            PROJECT_ID = Environment.GetEnvironmentVariable("SA_EMAIL") ?? "not-set";
            SERVICE_ACCOUNT = Environment.GetEnvironmentVariable("PROJECT_ID") ?? "not-set";
            SHEET_ID = Environment.GetEnvironmentVariable("SHEET_ID") ?? "not-set";
        }

        private async Task<GsheetData> FetchAndParseDataFromEndpoint(string sheetRange)
        {
            // Best practice: Use IHttpClientFactory to create an HttpClient instance.
            var client = _httpClientFactory.CreateClient("MyApiClient");

            try
            {
                // In a real app, these would come from a secure config source.
                var token = await GetGcpToken();
                var uriPath = $"/v4/spreadsheets/{SHEET_ID}/values/{sheetRange}";
                using (var request = new HttpRequestMessage(HttpMethod.Get, uriPath))
                {
                    request.Headers.Add("Authorization", $"Bearer {token}");

                    var response = await client.SendAsync(request);

                    if (response.IsSuccessStatusCode)
                    {
                        string jsonContent = await response.Content.ReadAsStringAsync();
                        Console.WriteLine("Request successful. Parsing JSON content.");
                        // Deserialize the JSON string into our C# object model.
                        return JsonSerializer.Deserialize<GsheetData>(jsonContent);
                    }
                    else
                    {
                        // Handle non-successful status codes
                        string errorContent = await response.Content.ReadAsStringAsync();
                        Console.WriteLine($"Error: {response.StatusCode} - {errorContent}");
                        return null;
                    }
                }
            }
            catch (HttpRequestException e)
            {
                Console.WriteLine($"HTTP Request Exception: {e.Message}");
                return null;
            }
            catch (JsonException e)
            {
                Console.WriteLine($"JSON Parsing Exception: {e.Message}");
                return null;
            }
        }

        public async Task<GsheetData> GetAccessControlRules()
        {
            return await _memoryCache.GetOrCreateAsync(
                "AccessRules",
                async cacheEntry =>
                {
                    cacheEntry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(2);
                    Console.WriteLine("Cache miss. Fetching access rules from remote source...");
                    return await FetchAndParseDataFromEndpoint(ACL_RANGE);
                }
            );
        }

        public async Task<GsheetData> GetRoles()
        {
            return await _memoryCache.GetOrCreateAsync(
                "Roles",
                async cacheEntry =>
                {
                    cacheEntry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(3);
                    Console.WriteLine("Cache miss. Fetching roles from remote source...");
                    return await FetchAndParseDataFromEndpoint(ROLES_RANGE);
                }
            );
        }

        public async Task<String> GetGcpToken()
        {
            return await _memoryCache.GetOrCreateAsync(
                "access_token",
                async cacheEntry =>
                {
                    cacheEntry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(9);
                    Console.WriteLine("Cache miss. Generating a token...");
                    return await TokenService.LoadGcpAccessTokenAsync(PROJECT_ID, SERVICE_ACCOUNT);
                }
            );
        }
    }
}
