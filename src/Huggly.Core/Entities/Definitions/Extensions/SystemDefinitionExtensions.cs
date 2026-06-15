namespace Huggly.Core.Entities.Definitions.Extensions;

public static class SystemDefinitionExtensions
{
  public static Dictionary<string, object> ResolveData(this SystemDefinition system, string environment)
  {
    if (!system.LandingZones.TryGetValue(environment, out var zone))
    {
      return system.Data;
    }

    return system
          .Data
          .Concat(zone.Data)
          .GroupBy(kv => kv.Key)
          .ToDictionary(g => g.Key, g => g.Last().Value);
  }

  public static IEnumerable<(string Environment, Dictionary<string, object> Data)> ResolveAll(
      this SystemDefinition system)
  {
    if (system.LandingZones.Count == 0)
    {
      yield return ("default", system.ResolveData("default"));
      yield break;
    }

    foreach (var name in system.LandingZones.Keys)
    {
      yield return (name, system.ResolveData(name));
    }
  }

}