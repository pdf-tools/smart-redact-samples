/// <summary>
/// Full Smart Redact workflow using the Manager API (HttpClient only).
///
/// Walks through every step of the Smart Redact Manager API:
///   1. Upload a PDF
///   2. Run Sensitive Information Detection
///   3. Run Sensitive Information Redaction
///   4. Download the redacted PDF
///
/// Usage:
///     dotnet run -- &lt;input-pdf&gt; [output-pdf]
///
/// If no output path is given, the redacted file is saved as
/// "&lt;input-basename&gt;_redacted.pdf" in the current directory.
///
/// Environment variables:
///     MANAGER_URL  - Smart Redact Manager base URL (default: http://localhost:9982)
///
/// See https://www.pdf-tools.com/docs/smart-redact for full API documentation.
/// </summary>

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

const int PollIntervalMs = 2000;
const int DefaultHttpTimeoutSeconds = 120;
const int DefaultJobTimeoutSeconds = 3600;
const string DefaultManagerUrl = "http://localhost:9982";
const string Separator = "------------------------------------------------------------";

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: dotnet run -- <input-pdf> [output-pdf]");
    return 1;
}

var inputPath = args[0];
if (!File.Exists(inputPath))
{
    Console.Error.WriteLine($"Error: File not found: {inputPath}");
    return 1;
}

var outputPath = args.Length >= 2
    ? args[1]
    : Path.GetFileNameWithoutExtension(inputPath) + "_redacted.pdf";

var baseUrl = (Environment.GetEnvironmentVariable("MANAGER_URL") ?? DefaultManagerUrl).TrimEnd('/');
var httpTimeoutSeconds = GetTimeoutSeconds("SMART_REDACT_HTTP_TIMEOUT_SECONDS", DefaultHttpTimeoutSeconds);
var jobTimeoutSeconds = GetTimeoutSeconds("SMART_REDACT_JOB_TIMEOUT_SECONDS", DefaultJobTimeoutSeconds);

Console.WriteLine($"Smart Redact Manager URL: {baseUrl}");
Console.WriteLine($"Input file:               {inputPath}");
Console.WriteLine($"Output file:              {outputPath}");

using var client = new HttpClient
{
    BaseAddress = new Uri(baseUrl)
};

var jsonOptions = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
};

try
{
PrintStep(1, "Upload PDF");

using var fileStream = File.OpenRead(inputPath);
using var formContent = new MultipartFormDataContent();
formContent.Add(new StreamContent(fileStream), "file", Path.GetFileName(inputPath));

Console.WriteLine($"  POST {baseUrl}/v1/files/upload/fromLocal");
var uploadResponse = await PostAsyncWithTimeout(client, "/v1/files/upload/fromLocal", formContent, httpTimeoutSeconds);
uploadResponse.EnsureSuccessStatusCode();

var uploadResult = await ReadJsonElementAsync(uploadResponse, jsonOptions);
var pdfFileId = GetRequiredString(uploadResult, "fileId");
var pdfDekToken = GetRequiredString(uploadResult, "dekToken");

PrintJson("Upload response", uploadResult);

PrintStep(2, "Sensitive Information Detection");

var detectionPayload = new
{
    pdfFileId,
    dekToken = pdfDekToken,
    processingMode = "sync"
};

Console.WriteLine($"  POST {baseUrl}/v1/jobs/detection");
Console.WriteLine($"  Payload: {JsonSerializer.Serialize(detectionPayload)}");

var detectionStartResponse = await PostAsJsonWithTimeout(client, "/v1/jobs/detection", detectionPayload, jobTimeoutSeconds);
detectionStartResponse.EnsureSuccessStatusCode();

var detectionStart = await ReadJsonElementAsync(detectionStartResponse, jsonOptions);
PrintJson("Detection start response", detectionStart);

var detectionResult = await ResolveJobResponse(client, "detection", detectionStart, jsonOptions);
if (TryGetString(detectionStart, "jobStatus") == "inProgress")
{
    PrintJson("Detection result", detectionResult);
}
EnsureJobSucceeded(detectionResult, "Detection");

var fdfFile = GetOutputFile(detectionStart, "fdf") ?? GetOutputFile(detectionResult, "fdf");
if (fdfFile is null)
{
    Console.Error.WriteLine("Error: Detection did not return an FDF output file.");
    return 1;
}

var fdfFileId = GetRequiredString(fdfFile.Value, "fileId");
var fdfDekToken = GetRequiredString(fdfFile.Value, "dekToken");
var redactions = GetRequiredRedactions(detectionResult);

Console.WriteLine();
Console.WriteLine($"FDF fileId: {fdfFileId}");
Console.WriteLine($"Redactions: {redactions.GetArrayLength()}");

PrintStep(3, "Sensitive Information Redaction");

var redactionPayload = new
{
    pdfFileId,
    fdfFileId,
    pdfDekToken,
    fdfDekToken,
    redactionInput = new
    {
        redactions = redactions.Clone()
    },
    processingMode = "sync"
};

Console.WriteLine($"  POST {baseUrl}/v1/jobs/redaction");
Console.WriteLine($"  Payload: {JsonSerializer.Serialize(redactionPayload)}");

var redactionStartResponse = await PostAsJsonWithTimeout(client, "/v1/jobs/redaction", redactionPayload, jobTimeoutSeconds);
redactionStartResponse.EnsureSuccessStatusCode();

var redactionStart = await ReadJsonElementAsync(redactionStartResponse, jsonOptions);
PrintJson("Redaction start response", redactionStart);

var redactionResult = await ResolveJobResponse(client, "redaction", redactionStart, jsonOptions);
if (TryGetString(redactionStart, "jobStatus") == "inProgress")
{
    PrintJson("Redaction result", redactionResult);
}
EnsureJobSucceeded(redactionResult, "Redaction");

var redactedPdf = GetOutputFile(redactionStart, "pdf") ?? GetOutputFile(redactionResult, "pdf");
if (redactedPdf is null)
{
    Console.Error.WriteLine("Error: Redaction did not return a downloadable PDF output.");
    return 1;
}

var redactedPdfFileId = GetRequiredString(redactedPdf.Value, "fileId");
var redactedPdfDekToken = GetRequiredString(redactedPdf.Value, "dekToken");

PrintStep(4, "Download Redacted PDF");

var downloadPayload = new
{
    fileId = redactedPdfFileId,
    dekToken = redactedPdfDekToken
};

Console.WriteLine($"  POST {baseUrl}/v1/files/download");
Console.WriteLine($"  Payload: {JsonSerializer.Serialize(downloadPayload)}");

var downloadResponse = await PostAsJsonWithTimeout(client, "/v1/files/download", downloadPayload, httpTimeoutSeconds);
downloadResponse.EnsureSuccessStatusCode();

var fileBytes = await downloadResponse.Content.ReadAsByteArrayAsync();
await File.WriteAllBytesAsync(outputPath, fileBytes);
Console.WriteLine($"  Wrote {fileBytes.Length} bytes to {outputPath}");

Console.WriteLine();
Console.WriteLine(Separator);
Console.WriteLine("  Workflow complete!");
Console.WriteLine($"  Redacted PDF saved to: {outputPath}");
Console.WriteLine(Separator);

return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

void PrintStep(int number, string title)
{
    Console.WriteLine();
    Console.WriteLine(Separator);
    Console.WriteLine($"  Step {number}: {title}");
    Console.WriteLine(Separator);
}

void PrintJson(string label, JsonElement data)
{
    Console.WriteLine();
    Console.WriteLine($"{label}:");
    Console.WriteLine(JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true }));
}

async Task<JsonElement> ReadJsonElementAsync(HttpResponseMessage response, JsonSerializerOptions jsonOptions)
{
    var element = await response.Content.ReadFromJsonAsync<JsonElement>(jsonOptions);
    return element;
}

async Task<JsonElement> ResolveJobResponse(
    HttpClient client,
    string jobType,
    JsonElement initialResponse,
    JsonSerializerOptions jsonOptions)
{
    if (TryGetString(initialResponse, "jobStatus") == "inProgress")
    {
        var jobId = GetRequiredString(initialResponse, "jobId");
        return await PollJob(client, jobType, jobId, jsonOptions);
    }

    return initialResponse;
}

async Task<JsonElement> PollJob(
    HttpClient client,
    string jobType,
    string jobId,
    JsonSerializerOptions jsonOptions)
{
    var url = $"/v1/jobs/{jobType}/{jobId}/result";
    Console.WriteLine($"  Polling GET {client.BaseAddress}{url.TrimStart('/')} ...");

    var attempts = 0;
    while (true)
    {
        var response = await GetAsyncWithTimeout(client, url, httpTimeoutSeconds);
        attempts++;

        if (response.StatusCode == HttpStatusCode.OK)
        {
            Console.WriteLine($"  Job finished after {attempts} poll(s).");
            return await ReadJsonElementAsync(response, jsonOptions);
        }

        if (response.StatusCode == HttpStatusCode.Accepted)
        {
            Console.WriteLine($"  Poll {attempts}: still in progress ...");
            await Task.Delay(PollIntervalMs);
            continue;
        }

        response.EnsureSuccessStatusCode();
    }
}

async Task<HttpResponseMessage> PostAsyncWithTimeout(
    HttpClient client,
    string url,
    HttpContent content,
    int timeoutSeconds)
{
    using var cts = CreateTimeoutTokenSource(timeoutSeconds);
    try
    {
        return await client.PostAsync(url, content, cts.Token);
    }
    catch (OperationCanceledException) when (cts.IsCancellationRequested)
    {
        throw new TimeoutException($"Request to {url} timed out after {timeoutSeconds} seconds.");
    }
}

async Task<HttpResponseMessage> PostAsJsonWithTimeout(
    HttpClient client,
    string url,
    object payload,
    int timeoutSeconds)
{
    using var cts = CreateTimeoutTokenSource(timeoutSeconds);
    try
    {
        return await client.PostAsJsonAsync(url, payload, cts.Token);
    }
    catch (OperationCanceledException) when (cts.IsCancellationRequested)
    {
        throw new TimeoutException($"Request to {url} timed out after {timeoutSeconds} seconds.");
    }
}

async Task<HttpResponseMessage> GetAsyncWithTimeout(HttpClient client, string url, int timeoutSeconds)
{
    using var cts = CreateTimeoutTokenSource(timeoutSeconds);
    try
    {
        return await client.GetAsync(url, cts.Token);
    }
    catch (OperationCanceledException) when (cts.IsCancellationRequested)
    {
        throw new TimeoutException($"Request to {url} timed out after {timeoutSeconds} seconds.");
    }
}

CancellationTokenSource CreateTimeoutTokenSource(int timeoutSeconds)
{
    return new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));
}

JsonElement? GetOutputFile(JsonElement response, string fileCode)
{
    if (!response.TryGetProperty("outputFiles", out var outputFiles) || outputFiles.ValueKind != JsonValueKind.Array)
    {
        return null;
    }

    foreach (var outputFile in outputFiles.EnumerateArray())
    {
        if (TryGetString(outputFile, "fileCode") == fileCode)
        {
            return outputFile.Clone();
        }
    }

    return null;
}

void EnsureJobSucceeded(JsonElement response, string stageName)
{
    var jobStatus = TryGetString(response, "jobStatus");
    var hasErrorObject = TryGetErrorObject(response, out var error);
    if (jobStatus != "error" && !hasErrorObject)
    {
        return;
    }

    var title = error.HasValue ? TryGetString(error.Value, "title") : null;
    var detail = error.HasValue ? TryGetString(error.Value, "detail") : null;
    var traceId = error.HasValue ? TryGetString(error.Value, "traceId") : null;

    var parts = new List<string>
    {
        title ?? $"{stageName} job failed."
    };

    if (!string.IsNullOrEmpty(detail))
    {
        parts.Add($"Detail: {detail}");
    }

    if (!string.IsNullOrEmpty(traceId))
    {
        parts.Add($"TraceId: {traceId}");
    }

    throw new InvalidOperationException(string.Join(" ", parts));
}

JsonElement GetRequiredRedactions(JsonElement detectionResponse)
{
    if (!detectionResponse.TryGetProperty("result", out var result) || result.ValueKind != JsonValueKind.Object)
    {
        throw new InvalidOperationException("Detection response did not include a result object.");
    }

    if (!result.TryGetProperty("redactions", out var redactions) || redactions.ValueKind != JsonValueKind.Array)
    {
        throw new InvalidOperationException("Detection response did not include a redactions array.");
    }

    return redactions.Clone();
}

string GetRequiredString(JsonElement element, string propertyName)
{
    var value = TryGetString(element, propertyName);
    if (string.IsNullOrEmpty(value))
    {
        throw new InvalidOperationException($"Missing required string property: {propertyName}");
    }

    return value;
}

int GetTimeoutSeconds(string environmentVariable, int defaultValue)
{
    var value = Environment.GetEnvironmentVariable(environmentVariable);
    if (string.IsNullOrWhiteSpace(value))
    {
        return defaultValue;
    }

    if (!int.TryParse(value, out var timeoutSeconds) || timeoutSeconds <= 0)
    {
        throw new InvalidOperationException(
            $"{environmentVariable} must be a positive integer. Current value: {value}");
    }

    return timeoutSeconds;
}

string? TryGetString(JsonElement element, string propertyName)
{
    if (element.TryGetProperty(propertyName, out var value) && value.ValueKind == JsonValueKind.String)
    {
        return value.GetString();
    }

    return null;
}

bool TryGetErrorObject(JsonElement response, out JsonElement? error)
{
    if (response.TryGetProperty("error", out var errorValue) &&
        errorValue.ValueKind == JsonValueKind.Object &&
        errorValue.EnumerateObject().Any())
    {
        error = errorValue.Clone();
        return true;
    }

    error = null;
    return false;
}
