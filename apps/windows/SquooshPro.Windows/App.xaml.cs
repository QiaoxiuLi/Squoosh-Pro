using Microsoft.UI.Xaml;

namespace SquooshPro.Windows;

public partial class App : Application
{
    private Window? window;

    public App()
    {
        InitializeComponent();
        UnhandledException += (_, args) =>
        {
            UserStorage.AppendDiagnostic($"Unhandled: {args.Exception}");
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var startup = Environment.GetCommandLineArgs().Skip(1).ToArray();
        for (var index = 0; index < startup.Length - 1; index++)
        {
            if (startup[index] == "--test-data-root")
                Environment.SetEnvironmentVariable("SQUOOSH_PRO_DATA_ROOT", startup[index + 1]);
        }
        window = new MainWindow(startup);
        window.Activate();
    }
}
