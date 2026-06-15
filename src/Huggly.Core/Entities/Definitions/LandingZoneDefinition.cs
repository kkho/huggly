
using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions;

public record LandingZoneDefinition
{
  [YamlMember(Alias = "data")]
  public Dictionary<string, object> Data { get; init; } = [];
}