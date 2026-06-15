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
  private readonly List<(DocumentEnvelope Envelope, YamlDocument Document)> _unresolved = [];

  public Dictionary<string, SystemContext> Systems { get; } = new();

  private readonly IDeserializer _deserializer = new DeserializerBuilder()
      .IgnoreUnmatchedProperties()
      .Build();

  public void Load(string yaml)
  {
    var yamlStream = new YamlStream();
    yamlStream.Load(new StringReader(yaml));

    foreach (var document in yamlStream.Documents)
    {
      var envelope = _deserializer.DeserializeYaml<DocumentEnvelope>(document);

      switch (envelope.Kind)
      {
        case DefinitionKind.System:
          var system = _deserializer.DeserializeYaml<SystemDefinition>(document);
          Systems[system.Name] = new SystemContext
          {
            System = system
          };
          break;

        default:
          _unresolved.Add((envelope, document));
          break;
      }
    }
  }

  public void Resolve()
  {
    foreach (var (envelope, document) in _unresolved)
    {
      AttachToSystem(envelope, document);
    }

    _unresolved.Clear();
  }

  private void AttachToSystem(DocumentEnvelope envelope, YamlDocument document)
  {
    if (!Systems.TryGetValue(envelope.System, out var context))
    {
      return;
    }

    switch (envelope.Kind)
    {
      case DefinitionKind.AppServicePlan:
        context.AppServicePlans.Add(_deserializer.DeserializeYaml<AppServicePlanDefinition>(document));
        break;
      case DefinitionKind.AppService:
        context.AppServices.Add(_deserializer.DeserializeYaml<AppServiceDefinition>(document));
        break;
    }

  }
}