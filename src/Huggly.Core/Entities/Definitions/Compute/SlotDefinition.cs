using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions.Compute;

// azurerm_linux_web_app_slot / azurerm_windows_web_app_slot
public record SlotDefinition
{
  [YamlMember(Alias = "name")]
  public string Name { get; init; } = "staging";

  [YamlMember(Alias = "appSettings")]
  public Dictionary<string, string> AppSettings { get; init; } = [];

  [YamlMember(Alias = "siteConfig")]
  public SiteConfigDefinition? SiteConfig { get; init; }
}