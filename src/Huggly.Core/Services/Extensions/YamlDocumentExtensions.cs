using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;

namespace Huggly.Core.Entities.Definitions.Extensions;

public static class YamlDocumentExtensions
{
  public static T? DeserializeYaml<T>(this IDeserializer deserializer, YamlDocument document)
  {
    var stream = new YamlStream(document);
    using var writer = new StringWriter();
    stream.Save(writer, assignAnchors: false);
    return deserializer.Deserialize<T>(writer.ToString());
  }
}