using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions.Compute;

// azurerm_linux_web_app / azurerm_windows_web_app
public record AppServiceDefinition
{
  [YamlMember(Alias = "name")]
  public string Name { get; init; } = "";

  [YamlMember(Alias = "servicePlan")]
  public string ServicePlan { get; init; } = ""; // references ServicePlanDefinition.Name

  [YamlMember(Alias = "landing-zone")]
  public Dictionary<string, AppServiceOverride> LandingZones { get; init; } = [];

  [YamlMember(Alias = "httpsOnly")]
  public bool HttpsOnly { get; init; } = true;

  [YamlMember(Alias = "appSettings")]
  public Dictionary<string, string> AppSettings { get; init; } = [];

  [YamlMember(Alias = "identity")]
  public IdentityDefinition? Identity { get; init; }

  [YamlMember(Alias = "siteConfig")]
  public SiteConfigDefinition SiteConfig { get; init; } = new();

  [YamlMember(Alias = "vnetIntegration")]
  public VnetIntegrationDefinition? VnetIntegration { get; init; }

  [YamlMember(Alias = "slots")]
  public List<SlotDefinition> Slots { get; init; } = [];

  [YamlMember(Alias = "customDomains")]
  public List<string> CustomDomains { get; init; } = [];
}

public record SiteConfigDefinition
{
  [YamlMember(Alias = "alwaysOn")]
  public bool AlwaysOn { get; init; } = false;

  [YamlMember(Alias = "http2Enabled")]
  public bool Http2Enabled { get; init; } = false;

  [YamlMember(Alias = "minimumTlsVersion")]
  public string MinimumTlsVersion { get; init; } = "1.2";

  [YamlMember(Alias = "ftpsState")]
  public string FtpsState { get; init; } = "Disabled"; // Disabled, AllAllowed, FtpsOnly

  [YamlMember(Alias = "healthCheckPath")]
  public string? HealthCheckPath { get; init; }

  [YamlMember(Alias = "applicationStack")]
  public ApplicationStackDefinition? ApplicationStack { get; init; }
}

public record ApplicationStackDefinition
{
  [YamlMember(Alias = "dotnetVersion")]
  public string? DotnetVersion { get; init; } // e.g. "8.0"

  [YamlMember(Alias = "nodeVersion")]
  public string? NodeVersion { get; init; } // e.g. "20-lts"

  [YamlMember(Alias = "pythonVersion")]
  public string? PythonVersion { get; init; } // e.g. "3.12"

  [YamlMember(Alias = "javaVersion")]
  public string? JavaVersion { get; init; } // e.g. "21"
}

public record IdentityDefinition
{
  [YamlMember(Alias = "type")]
  public string Type { get; init; } = "SystemAssigned"; // SystemAssigned, UserAssigned, SystemAssigned, UserAssigned

  [YamlMember(Alias = "identityIds")]
  public List<string> IdentityIds { get; init; } = []; // required for UserAssigned
}

// Nested: virtual_network_subnet_id — azurerm_app_service_virtual_network_swift_connection
public record VnetIntegrationDefinition
{
  [YamlMember(Alias = "subnetId")]
  public string SubnetId { get; init; } = "";
}

public record AppServiceOverride
{
  [YamlMember(Alias = "appSettings")]
  public Dictionary<string, string> AppSettings { get; init; } = [];
}
