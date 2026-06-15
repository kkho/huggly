using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Azure.Compute;

public record AppService
{
  [YamlMember(Alias = "name")]
  public string Name { get; init; } = string.Empty;


}