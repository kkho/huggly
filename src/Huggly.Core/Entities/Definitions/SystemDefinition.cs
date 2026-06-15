
using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions;

public record SystemDefinition
{
  [YamlMember(Alias = "kind")]
  public string Kind { get; init; } = string.Empty;

  [YamlMember(Alias = "data")]
  public Dictionary<string, object> Data { get; init; } = [];

  [YamlMember(Alias = "name")]
  public string Name { get; init; } = string.Empty;

  [YamlMember(Alias = "landing-zone")]
  public Dictionary<string, LandingZoneDefinition> LandingZones { get; init; } = [];
}