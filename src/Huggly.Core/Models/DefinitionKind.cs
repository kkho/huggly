using System.Runtime.Serialization;

namespace Huggly.Core.Entities.Definitions.Extensions;

public enum DefinitionKind
{
  [EnumMember(Value = "System")] System,
  [EnumMember(Value = "AksCluster")] AksCluster,  // handle hyphens
  [EnumMember(Value = "AppServicePlan")] AppServicePlan,
  [EnumMember(Value = "AppService")] AppService
}