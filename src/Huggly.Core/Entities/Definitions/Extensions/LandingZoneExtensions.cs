using Huggly.Core.Entities.Definitions.Compute;

namespace Huggly.Core.Entities.Definitions.Extensions;

public static class LandingZoneExtensions
{
  public static AppServiceDefinition ResolveFor(this AppServiceDefinition app, string environment)
  {
    if (!app.LandingZones.TryGetValue(environment, out var zone))
      return app;

    var resolved = new Dictionary<string, string>(app.AppSettings);
    foreach (var (key, value) in zone.AppSettings)
      resolved[key] = value;

    return app with { AppSettings = resolved };
  }
}