using FileMCP.Core;
using Microsoft.Win32;
using System.Windows;
using Color = System.Windows.Media.Color;
using Colors = System.Windows.Media.Colors;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;
using SystemColors = System.Windows.SystemColors;

namespace FileMCP.App;

public partial class App : System.Windows.Application
{
    private MainWindow? _window;
    private DesktopSingleInstanceCoordinator? _singleInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        ApplySystemThemeResources();
        SystemParameters.StaticPropertyChanged += OnSystemParametersChanged;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;

        _singleInstance = new DesktopSingleInstanceCoordinator("FileMCP.Desktop.v1");
        if (!_singleInstance.IsPrimary)
        {
            try { _singleInstance.SignalPrimaryAsync(TimeSpan.FromSeconds(2)).GetAwaiter().GetResult(); } catch { }
            _singleInstance.Dispose();
            _singleInstance = null;
            Shutdown(0);
            return;
        }

        _window = new MainWindow();
        MainWindow = _window;
        SessionEnding += (_, _) => _window.ShutdownForSystemSession();
        _singleInstance.StartActivationListener(() =>
            Dispatcher.BeginInvoke(new Action(() => _window?.ActivateFromSecondaryLaunch())));
        _window.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemParameters.StaticPropertyChanged -= OnSystemParametersChanged;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        _singleInstance?.Dispose();
        _singleInstance = null;
        base.OnExit(e);
    }

    private void OnSystemParametersChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(SystemParameters.HighContrast) or nameof(SystemParameters.WindowGlassColor))
            Dispatcher.BeginInvoke(ApplySystemThemeResources);
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category is UserPreferenceCategory.Color or UserPreferenceCategory.General or UserPreferenceCategory.VisualStyle)
            Dispatcher.BeginInvoke(ApplySystemThemeResources);
    }

    private void ApplySystemThemeResources()
    {
        if (SystemParameters.HighContrast)
        {
            SetBrush("FileMcpSurfaceAppBrush", SystemColors.WindowColor);
            SetBrush("FileMcpSurfaceSidebarBrush", SystemColors.ControlColor);
            SetBrush("FileMcpSurfaceCardBrush", SystemColors.WindowColor);
            SetBrush("FileMcpSurfaceRaisedBrush", SystemColors.ControlColor);
            SetBrush("FileMcpSurfaceCodeBrush", SystemColors.WindowColor);
            SetBrush("FileMcpBorderSubtleBrush", SystemColors.WindowTextColor);
            SetBrush("FileMcpBorderStrongBrush", SystemColors.WindowTextColor);
            SetBrush("FileMcpTextPrimaryBrush", SystemColors.WindowTextColor);
            SetBrush("FileMcpTextSecondaryBrush", SystemColors.WindowTextColor);
            SetBrush("FileMcpTextDisabledBrush", SystemColors.GrayTextColor);
            SetBrush("FileMcpCodeTextBrush", SystemColors.WindowTextColor);
            SetBrush("FileMcpAccentPrimaryBrush", SystemColors.HighlightColor);
            SetStatusBrushes(SystemColors.HighlightColor);
            return;
        }

        if (UsesDarkAppsTheme())
        {
            SetBrush("FileMcpSurfaceAppBrush", Color.FromRgb(0x1B, 0x1D, 0x22));
            SetBrush("FileMcpSurfaceSidebarBrush", Color.FromRgb(0x20, 0x23, 0x29));
            SetBrush("FileMcpSurfaceCardBrush", Color.FromRgb(0x24, 0x27, 0x2E));
            SetBrush("FileMcpSurfaceRaisedBrush", Color.FromRgb(0x2A, 0x2E, 0x36));
            SetBrush("FileMcpSurfaceCodeBrush", Color.FromRgb(0x11, 0x13, 0x17));
            SetBrush("FileMcpBorderSubtleBrush", Color.FromRgb(0x3A, 0x40, 0x4A));
            SetBrush("FileMcpBorderStrongBrush", Color.FromRgb(0x59, 0x61, 0x6D));
            SetBrush("FileMcpTextPrimaryBrush", Color.FromRgb(0xF4, 0xF6, 0xF8));
            SetBrush("FileMcpTextSecondaryBrush", Color.FromRgb(0xBD, 0xC5, 0xCF));
            SetBrush("FileMcpTextDisabledBrush", Color.FromRgb(0x78, 0x81, 0x8C));
            SetBrush("FileMcpCodeTextBrush", Color.FromRgb(0xF4, 0xF6, 0xF8));
            SetBrush("FileMcpAccentPrimaryBrush", Color.FromRgb(0x60, 0xA5, 0xFA));
            SetBrush("FileMcpStatusInfoBrush", Color.FromRgb(0x60, 0xA5, 0xFA));
            SetBrush("FileMcpStatusSuccessBrush", Color.FromRgb(0x4A, 0xDE, 0x80));
            SetBrush("FileMcpStatusWarningBrush", Color.FromRgb(0xFB, 0xBF, 0x24));
            SetBrush("FileMcpStatusDangerBrush", Color.FromRgb(0xF8, 0x71, 0x71));
            SetBrush("FileMcpStatusNeutralBrush", Color.FromRgb(0xA3, 0xAC, 0xB9));
            SetBrush("FileMcpStatusStaleBrush", Color.FromRgb(0xC4, 0xA7, 0xFF));
            return;
        }

        SetBrush("FileMcpSurfaceAppBrush", Color.FromRgb(0xF7, 0xF8, 0xFA));
        SetBrush("FileMcpSurfaceSidebarBrush", Color.FromRgb(0xF1, 0xF3, 0xF6));
        SetBrush("FileMcpSurfaceCardBrush", Colors.White);
        SetBrush("FileMcpSurfaceRaisedBrush", Colors.White);
        SetBrush("FileMcpSurfaceCodeBrush", Color.FromRgb(0x16, 0x18, 0x1D));
        SetBrush("FileMcpBorderSubtleBrush", Color.FromRgb(0xE1, 0xE5, 0xEA));
        SetBrush("FileMcpBorderStrongBrush", Color.FromRgb(0xC4, 0xCA, 0xD2));
        SetBrush("FileMcpTextPrimaryBrush", Color.FromRgb(0x17, 0x1A, 0x1F));
        SetBrush("FileMcpTextSecondaryBrush", Color.FromRgb(0x5D, 0x66, 0x72));
        SetBrush("FileMcpTextDisabledBrush", Color.FromRgb(0x92, 0x9A, 0xA4));
        SetBrush("FileMcpCodeTextBrush", Colors.White);
        SetBrush("FileMcpAccentPrimaryBrush", Color.FromRgb(0x25, 0x63, 0xEB));
        SetBrush("FileMcpStatusInfoBrush", Color.FromRgb(0x25, 0x63, 0xEB));
        SetBrush("FileMcpStatusSuccessBrush", Color.FromRgb(0x15, 0x80, 0x3D));
        SetBrush("FileMcpStatusWarningBrush", Color.FromRgb(0xB4, 0x53, 0x09));
        SetBrush("FileMcpStatusDangerBrush", Color.FromRgb(0xB9, 0x1C, 0x1C));
        SetBrush("FileMcpStatusNeutralBrush", Color.FromRgb(0x66, 0x70, 0x85));
        SetBrush("FileMcpStatusStaleBrush", Color.FromRgb(0x7C, 0x3A, 0xED));
    }

    private void SetStatusBrushes(Color color)
    {
        foreach (var key in new[] { "FileMcpStatusInfoBrush", "FileMcpStatusSuccessBrush", "FileMcpStatusWarningBrush", "FileMcpStatusDangerBrush", "FileMcpStatusNeutralBrush", "FileMcpStatusStaleBrush" })
            SetBrush(key, color);
    }

    private void SetBrush(string key, Color color)
    {
        var brush = new SolidColorBrush(color);
        brush.Freeze();
        Resources[key] = brush;
    }

    private static bool UsesDarkAppsTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        }
        catch
        {
            return false;
        }
    }
}
