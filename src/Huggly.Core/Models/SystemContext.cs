

using Huggly.Core.Entities.Definitions;
using Huggly.Core.Entities.Definitions.Compute;

namespace Huggly.Core.Models;

public class SystemContext
{
  public SystemDefinition System { get; init; } = new();
  public List<AppServicePlanDefinition> AppServicePlans { get; init; } = [];
  public List<AppServiceDefinition> AppServices { get; init; } = [];
}