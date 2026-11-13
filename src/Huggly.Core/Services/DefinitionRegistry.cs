using YamlDotNet.Core;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;
using YamlDotNet.Serialization.Converters;
using Huggly.Core.Entities.Definitions;
using Huggly.Core.Entities.Definitions.Compute;
using Huggly.Core.Models;
using Huggly.Core.Entities.Definitions.Extensions;

namespace Huggly.Core.Services;

public class DefinitionRegistry
{
  private readonly List<(DocumentEnvelope Envelope, YamlDocument Document, string Source)> _unresolved = [];

  public Dictionary<string, SystemContext> Systems { get; } = new();

  private readonly IDeserializer _deserializer = new DeserializerBuilder()
      .IgnoreUnmatchedProperties()
      .Build();

  public void Load(string yaml, string source)
  {
    try
    {
      var yamlStream = new YamlStream();
      yamlStream.Load(new StringReader(yaml));

      foreach (var document in yamlStream.Documents)
      {
        var envelope = _deserializer.DeserializeYaml<DocumentEnvelope>(document);
        if (envelope is null)
        {
          continue; // empty document, e.g. a trailing '---'
        }

        switch (envelope.Kind)
        {
          case DefinitionKind.System:
            var system = _deserializer.DeserializeYaml<SystemDefinition>(document);
            if (string.IsNullOrWhiteSpace(system?.Name))
            {
              throw new InvalidOperationException($"{source}: missing 'kind:', or a System without 'name:'.");
            }
            Systems[system.Name] = new SystemContext
            {
              System = system
            };
            break;

          default:
            _unresolved.Add((envelope, document, source));
            break;
        }
      }
    }
    catch (YamlException ex)
    {
      throw new InvalidOperationException($"{source}: {ex.Message} {ex.InnerException?.Message}", ex);
    }
  }

  public void Resolve()
  {
    foreach (var (envelope, document, source) in _unresolved)
    {
      AttachToSystem(envelope, document, source);
    }

    _unresolved.Clear();
  }

  private void AttachToSystem(DocumentEnvelope envelope, YamlDocument document, string source)
  {
    if (!Systems.TryGetValue(envelope.System, out var context))
    {
      var known = Systems.Count == 0 ? "none" : string.Join(", ", Systems.Keys);
      throw new InvalidOperationException(
        $"{source}: {envelope.Kind} refers to system '{envelope.System}', but no system with that name exists. Known systems: {known}");
    }

    switch (envelope.Kind)
    {
      case DefinitionKind.AppServicePlan:
        context.AppServicePlans.Add(_deserializer.DeserializeYaml<AppServicePlanDefinition>(document));
        break;
      case DefinitionKind.AppService:
        context.AppServices.Add(_deserializer.DeserializeYaml<AppServiceDefinition>(document));
        break;
      default:
        throw new InvalidOperationException($"{source}: kind '{envelope.Kind}' is not supported yet.");
    }
  }
}