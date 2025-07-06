using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

public class TokenService
{
    // In a real application, you would use a logging framework like Serilog or Microsoft.Extensions.Logging
    // For this example, we'll use Console.WriteLine to represent logging.
    static System.IO.TextWriter log = System.Console.Out;
    static readonly String PROJECT_ID =
        Environment.GetEnvironmentVariable("PROJECT_ID") ?? "not-set";
    static readonly String SA_EMAIL = Environment.GetEnvironmentVariable("SA_EMAIL") ?? "not-set";

    // A single, static HttpClient can be reused for the application's lifetime.
    private static readonly HttpClient httpClient = new HttpClient();

    /// <summary>
    /// Checks if the application is running in a Google Cloud Run environment.
    /// Google Cloud Run automatically sets the K_SERVICE environment variable.
    /// </summary>
    public static bool IsRunningInCloud()
    {
        string kService = Environment.GetEnvironmentVariable("K_SERVICE");
        return !string.IsNullOrEmpty(kService);
    }

    /// <summary>
    /// Loads a GCP access token.
    /// If in Cloud Run, it fetches the token from the metadata server.
    /// Otherwise, it uses the local 'gcloud' CLI.
    /// </summary>
    /// <returns>The access token, or null if it cannot be retrieved.</returns>
    public static async Task<string> LoadGcpAccessTokenAsync()
    {
        if (IsRunningInCloud())
        {
            log.WriteLine("INFO: Running in Cloud Run, fetching token from metadata server...");
            const string metadataUrl =
                "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token";

            try
            {
                // Create a request with the required "Metadata-Flavor" header.
                var request = new HttpRequestMessage(HttpMethod.Get, metadataUrl);
                request.Headers.Add("Metadata-Flavor", "Google");

                HttpResponseMessage response = await httpClient.SendAsync(request);
                response.EnsureSuccessStatusCode(); // Throws an exception if the status is not 2xx

                string responseBody = await response.Content.ReadAsStringAsync();

                // Parse the JSON response to extract the token.
                var tokenResponse = JsonSerializer.Deserialize<Dictionary<string, object>>(
                    responseBody
                );

                if (
                    tokenResponse != null
                    && tokenResponse.TryGetValue("access_token", out object accessTokenObj)
                )
                {
                    string accessToken = accessTokenObj.ToString();
                    if (!string.IsNullOrEmpty(accessToken))
                    {
                        log.WriteLine("INFO: Successfully fetched token from metadata server.");
                        return accessToken;
                    }
                }
                log.WriteLine("ERROR: 'access_token' not found in metadata server response.");
                return null;
            }
            catch (Exception e)
            {
                log.WriteLine(
                    $"ERROR: Unexpected error fetching/parsing token from metadata server: {e.Message}"
                );
                return null;
            }
        }
        else
        {
            log.WriteLine("INFO: Not running in Cloud Run, using gcloud CLI for token...");
            if (string.IsNullOrEmpty(PROJECT_ID))
            {
                log.WriteLine(
                    "ERROR: environment variable PROJECT_ID is required for local 'gcloud' token retrieval."
                );
                return null;
            }
            if (string.IsNullOrEmpty(SA_EMAIL))
            {
                log.WriteLine(
                    "ERROR: environment variable SA_EMAIL is required for local 'gcloud' token retrieval."
                );
                return null;
            }
            return await ExecuteCommandAsync(
                "gcloud",
                "auth",
                "print-access-token",
                "--impersonate-service-account",
                SA_EMAIL,
                "--project",
                PROJECT_ID,
                "--scopes",
                "https://www.googleapis.com/auth/spreadsheets.readonly",
                "--quiet"
            );
        }
    }

    /// <summary>
    /// Asynchronously executes an external command and captures its output.
    /// </summary>
    /// <param name="command">The command and its arguments to execute.</param>
    /// <returns>The standard output of the command, or null on failure.</returns>
    private static async Task<string> ExecuteCommandAsync(params string[] command)
    {
        if (command.Length == 0)
            return null;

        var processStartInfo = new ProcessStartInfo
        {
            FileName = command[0],
            // Combine remaining parts as arguments, properly quoted.
            Arguments = string.Join(" ", command.Skip(1).Select(arg => $"\"{arg}\"")),
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        try
        {
            using var process = Process.Start(processStartInfo);
            if (process == null)
            {
                log.WriteLine($"ERROR: Failed to start process for command: {command[0]}");
                return null;
            }

            log.WriteLine(
                $"INFO: Executing command: {processStartInfo.FileName} {processStartInfo.Arguments}"
            );

            // Read both output and error streams asynchronously.
            Task<string> outputTask = process.StandardOutput.ReadToEndAsync();
            Task<string> errorTask = process.StandardError.ReadToEndAsync();

            // Wait for the process to exit with a timeout.
            bool finished =
                await Task.WhenAny(Task.Run(() => process.WaitForExit(60000)), outputTask)
                    == outputTask
                || process.HasExited;

            if (!finished)
            {
                process.Kill();
                throw new TimeoutException($"Command timed out: {string.Join(" ", command)}");
            }

            await Task.WhenAll(outputTask, errorTask);
            string output = await outputTask;
            string errorOutput = await errorTask;

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException(
                    $"Command failed with exit code {process.ExitCode}. "
                        + $"[{string.Join(" ", command)}] "
                        + $"Error: {errorOutput.Trim()}"
                );
            }
            return output.Trim();
        }
        catch (Exception ex)
        {
            log.WriteLine(
                $"ERROR: Exception executing command '{string.Join(" ", command)}': {ex.Message}"
            );
            return null;
        }
    }
}
