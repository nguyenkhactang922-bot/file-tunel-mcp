namespace FileMCP.App.Presentation;

public enum NavigationDestination
{
    Home,
    Workspaces,
    Activity,
    Changes,
    Repository,
    Terminal,
    Recovery,
    Evidence,
    Connections,
    Settings,
}

public sealed record NavigationDestinationDescriptor(
    NavigationDestination Destination,
    string Label,
    string IconKey,
    int Order);

public static class NavigationCatalog
{
    private static readonly NavigationDestinationDescriptor[] Items =
    [
        new(NavigationDestination.Home, "Home", "nav-home", 0),
        new(NavigationDestination.Workspaces, "Workspaces", "nav-workspaces", 10),
        new(NavigationDestination.Activity, "Activity", "nav-activity", 20),
        new(NavigationDestination.Changes, "Changes", "nav-changes", 30),
        new(NavigationDestination.Repository, "Repository", "nav-repository", 40),
        new(NavigationDestination.Terminal, "Terminal", "nav-terminal", 50),
        new(NavigationDestination.Recovery, "Recovery", "nav-recovery", 60),
        new(NavigationDestination.Evidence, "Evidence", "nav-evidence", 70),
        new(NavigationDestination.Connections, "Connections", "nav-connections", 80),
        new(NavigationDestination.Settings, "Settings", "nav-settings", 90),
    ];

    public static IReadOnlyList<NavigationDestinationDescriptor> All { get; } = Array.AsReadOnly(Items);

    public static NavigationDestinationDescriptor Describe(NavigationDestination destination) =>
        Items.First(item => item.Destination == destination);
}
