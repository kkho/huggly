using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions.Compute;

// azurerm_service_plan
public record AppServicePlanDefinition
{
  [YamlMember(Alias = "name")]
  public string Name { get; init; } = "";

  [YamlMember(Alias = "sku")]
  public string Sku { get; init; } = "B1"; // F1, B1-B3, S1-S3, P1v3-P3v3, EP1-EP3

  [YamlMember(Alias = "osType")]
  public string OsType { get; init; } = "Linux"; // Linux, Windows

  [YamlMember(Alias = "workerCount")]
  public int? WorkerCount { get; init; }

  [YamlMember(Alias = "zoneBalancing")]
  public bool ZoneBalancing { get; init; } = false;

  [YamlMember(Alias = "landing-zone")]
  public Dictionary<string, AppServicePlanOverride> LandingZones { get; init; } = [];
}

public record AppServicePlanOverride
{
  [YamlMember(Alias = "sku")]
  public string? Sku { get; init; }

  [YamlMember(Alias = "workerCount")]
  public int? WorkerCount { get; init; }
}