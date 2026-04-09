

using Microsoft.Extensions.Configuration;

var switchMappings = new Dictionary<string, string>
{
    { "-e", "Environment" },
    { "--environment", "Environment" },
    { "-c", "Action:Compile" },
    { "-r", "Action:Run" },
    { "-t", "Action:Test" }
};

var config = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile("appsettings.Development.json", optional: true, reloadOnChange: true)
    .AddCommandLine(args, switchMappings)
    .Build();

string environment = config["environment"] ?? "Production";

var actions = config.GetSection("Action").GetChildren().ToDictionary(x => x.Key, x => x.Value);

if (actions.Count(a => a.Value == "true") != 1)
{
    Console.WriteLine("Error: Please specify exactly one action (-c, -r, or -t).");
    return;
}

var command = actions.FirstOrDefault(a => a.Value == "true").Key;

if (command != null)
{
    switch(command.ToLower())
    {
        case "compile":
            Console.WriteLine($"Compiling in {environment} environment...");
            // Add compile logic here
            break;
        case "run":
            Console.WriteLine($"Running in {environment} environment...");
            // Add run logic here
            break;
        case "test":
            Console.WriteLine($"Testing in {environment} environment...");
            // Add test logic here
            break;
        default:
            Console.WriteLine("Error: Unknown action specified.");
            break;
    }
}
else
{
    Console.WriteLine("Error: No valid action was provided");
}


