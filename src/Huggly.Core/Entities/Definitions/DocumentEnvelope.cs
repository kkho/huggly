
using Huggly.Core.Entities.Definitions.Extensions;
using YamlDotNet.Serialization;

namespace Huggly.Core.Services;

public record DocumentEnvelope
{
  [YamlMember(Alias = "kind")]
  public DefinitionKind Kind { get; set; }

  [YamlMember(Alias = "system")]
  public string System { get; init; } = string.Empty;
}