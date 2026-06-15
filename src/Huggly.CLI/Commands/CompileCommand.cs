using Huggly.Core.Services;
using Huggly.Core.Entities.Definitions.Extensions;
using Huggly.Core.Models;
using Microsoft.Extensions.Logging;
using Scriban.Runtime;

namespace Huggly.CLI.Commands;

public class CompileCommand
{
  private readonly ILogger<CompileCommand> _logger;
  private readonly TemplateLoader _templateLoader;
  private readonly DefinitionRegistry _definitionRegistry;

  public CompileCommand(ILogger<CompileCommand> logger, TemplateLoader templateLoader, DefinitionRegistry registry)
  {
    _logger = logger;
    _templateLoader = templateLoader;
    _definitionRegistry = registry;
  }

  public async Task<int> ExecuteAsync(string definitionsPath, string selectedEnvironment, string outputPath, CancellationToken cancellationToken = default)
  {
    _logger.LogInformation("Loading definitions from {Path}... by environment {Environment}", definitionsPath, selectedEnvironment);

    try
    {
      var files = Directory.GetFiles(definitionsPath, "*.yaml", SearchOption.AllDirectories);

      foreach (var file in files)
      {
        var yaml = await File.ReadAllTextAsync(file, cancellationToken);
        _definitionRegistry.Load(yaml);
      }

      _definitionRegistry.Resolve();

      foreach (var (systemName, context) in _definitionRegistry.Systems)
      {
        _logger.LogInformation("Compiling system {System}...", systemName);

        foreach (var (environment, data) in context.System.ResolveAll())
        {
          if (!string.IsNullOrEmpty(selectedEnvironment) && selectedEnvironment != environment)
          {
            continue;
          }

          _logger.LogInformation("Processing environment {Environment}...", environment);
          var outputDirectory = Path.Combine(outputPath, environment, systemName);

          if (Directory.Exists(outputDirectory))
          {
            Directory.Delete(outputDirectory, recursive: true);
          }

          Directory.CreateDirectory(outputDirectory);

          var model = BuildModel(systemName, environment, data, context);
          await RenderSystemTemplateAsync(outputDirectory, model, context, cancellationToken);
        }
      }

      _logger.LogInformation("Compilation completed successfully");
      return 0; // Success
    }
    catch (Exception ex)
    {
      _logger.LogError(ex, "Compilation failed");
      return 1; // Failure
    }
  }

  private static ScriptObject BuildModel(string systemName, string environment, Dictionary<string, object> data, SystemContext context)
  {
    var model = new ScriptObject
    {
      { "system_name", systemName },
      { "environment", environment }
    };

    foreach (var (key, value) in data)
    {
      model.Add(key, value);
    }

    var resolvedApps = context.AppServices
    .Select(app => app.ResolveFor(environment))
    .ToList();

    model.Add("app_service_plans", context.AppServicePlans);
    model.Add("app_services", resolvedApps);

    return model;
  }

  private async Task RenderSystemTemplateAsync(string outputDirectory, ScriptObject model, SystemContext context, CancellationToken cancellationToken)
  {
    const string commonPrefix = "Huggly.Core.Templates.Files.Common.";
    const string systemPrefix = "Huggly.Core.Templates.Files.System.";
    const string computePrefix = "Huggly.Core.Templates.Files.Modules.compute.";

    await RenderFromPrefixAsync(systemPrefix, outputDirectory, model, cancellationToken);
    await RenderFromPrefixAsync(commonPrefix, outputDirectory, model, cancellationToken);
    await RenderModulesAsync(computePrefix, outputDirectory, model, cancellationToken);
  }

  private async Task RenderFromPrefixAsync(
    string prefix,
    string outputDirectory,
    ScriptObject model,
    CancellationToken cancellationToken,
    bool trimFirstSegment = false)
  {
    var resources = GetTemplateResources(prefix);

    foreach (var resourceName in resources)
    {
      var relativeName = resourceName.Replace(prefix, "");

      if (trimFirstSegment)
      {
        var firstSeparatorIndex = relativeName.IndexOf('.');
        if (firstSeparatorIndex >= 0 && firstSeparatorIndex < relativeName.Length - 1)
        {
          relativeName = relativeName[(firstSeparatorIndex + 1)..];
        }
      }

      var outputFile = relativeName.Replace(".scriban", "");

      var suffix = resourceName.Replace("Huggly.Core.", "");
      var content = await _templateLoader.RenderAsync(suffix, model, cancellationToken);
      await File.WriteAllTextAsync(Path.Combine(outputDirectory, outputFile), content, cancellationToken);
    }
  }

  private async Task RenderModulesAsync(string prefix, string outputDirectory, ScriptObject model, CancellationToken cancellationToken)
  {
    var resources = GetTemplateResources(prefix);

    foreach (var resourceName in resources)
    {
      var relativeName = resourceName.Replace(prefix, "");
      var outputFile = relativeName.Replace(".scriban", "");

      var modelKey = Path.GetFileNameWithoutExtension(outputFile);

      if (model[modelKey] is not System.Collections.IList list || list.Count == 0)
      {
        continue;
      }

      var suffix = resourceName.Replace("Huggly.Core.", "");
      var content = await _templateLoader.RenderAsync(suffix, model, cancellationToken);
      await File.WriteAllTextAsync(Path.Combine(outputDirectory, outputFile), content, cancellationToken);
    }


  }

  private static IEnumerable<string>? GetTemplateResources(string prefix) =>
    typeof(TemplateLoader).Assembly
        .GetManifestResourceNames()
        .Where(n => n.StartsWith(prefix) && n.EndsWith(".scriban"));
}
