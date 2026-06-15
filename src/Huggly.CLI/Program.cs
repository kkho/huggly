

using System.CommandLine;
using Huggly.CLI.Commands;
using Huggly.Core.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

// Build host with DI and logging
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton<DefinitionRegistry>();
builder.Services.AddTransient<TemplateLoader>();

// Configure services
builder.Services.AddTransient<CompileCommand>();
builder.Services.AddTransient<RunCommand>();
builder.Services.AddTransient<TestCommand>();

// Add configuration from appsettings.json
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile("appsettings.Development.json", optional: true, reloadOnChange: true);

var host = builder.Build();

// Create root command
var rootCommand = new RootCommand("Huggly CLI - Infrastructure as Code Generator");

var environmentOption = new Option<string>("--environment")
{
    Description = "Target environment (prod, dev, etc.)",
    DefaultValueFactory = _ => "dev"
};
environmentOption.Aliases.Add("-e");

var outputPathOption = new Option<string>("--output")
{
    Description = "Output path to write generated Terraform files",
    DefaultValueFactory = _ => "output"
};
outputPathOption.Aliases.Add("-o");

var definitionsPathOption = new Option<string>("--definitions")
{
    Description = "Path to directory containing YAML definition files",
    DefaultValueFactory = _ => "definitions"
};
definitionsPathOption.Aliases.Add("-d");


// Compile command
var compileCommand = new Command("compile", "Compile and generate infrastructure templates");
compileCommand.Options.Add(definitionsPathOption);
compileCommand.Options.Add(environmentOption);
compileCommand.Options.Add(outputPathOption);
compileCommand.SetAction(async (parseResult, cancellationToken) =>
{
    var definitions = parseResult.GetValue(definitionsPathOption)!;
    var environment = parseResult.GetValue(environmentOption)!;
    var output = parseResult.GetValue(outputPathOption)!;
    var cmd = host.Services.GetRequiredService<CompileCommand>();
    return await cmd.ExecuteAsync(definitions, environment, output, cancellationToken);
});

// Run command
var runCommand = new Command("run", "Execute and deploy infrastructure");
runCommand.Options.Add(environmentOption);
runCommand.SetAction(async parseResult =>
{
    var env = parseResult.GetValue(environmentOption)!;
    var cmd = host.Services.GetRequiredService<RunCommand>();
    return await cmd.ExecuteAsync(env);
});

// Test command
var testCommand = new Command("test", "Validate infrastructure configuration");
testCommand.Options.Add(environmentOption);
testCommand.SetAction(async parseResult =>
{
    var env = parseResult.GetValue(environmentOption)!;
    var cmd = host.Services.GetRequiredService<TestCommand>();
    return await cmd.ExecuteAsync(env);
});

// Add commands to root
rootCommand.Subcommands.Add(compileCommand);
rootCommand.Subcommands.Add(runCommand);
rootCommand.Subcommands.Add(testCommand);

// Invoke the command
return await rootCommand.Parse(args).InvokeAsync();
