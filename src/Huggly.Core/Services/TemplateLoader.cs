using System.Reflection;
using System.Text.RegularExpressions;
using Scriban;
using Scriban.Runtime;

namespace Huggly.Core.Services;

public class TemplateLoader
{
  private static readonly Assembly _assembly = typeof(TemplateLoader).Assembly;

  public async Task<string> RenderAsync(string resourceSuffix, ScriptObject model, CancellationToken cancellationToken = default)
  {
    var resourceName = $"Huggly.Core.{resourceSuffix.Replace('/', '.').Replace('\\', '.')}";
    await using var stream = _assembly.GetManifestResourceStream(resourceName) ??
      throw new FileNotFoundException($"Resource '{resourceName}' not found.");

    using var reader = new StreamReader(stream);
    var templateText = await reader.ReadToEndAsync(cancellationToken);

    var template = Template.Parse(templateText);
    if (template.HasErrors)
    {
      throw new InvalidOperationException(string.Join('\n', template.Messages));
    }

    var context = new TemplateContext();
    context.MemberRenamer = member =>
        Regex.Replace(member.Name, "([A-Z])", m => "_" + m.Value.ToLower()).TrimStart('_');
    context.PushGlobal(model);
    return await template.RenderAsync(context);
  }

}