using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using FileMCP.App.Presentation;

namespace FileMCP.App.Controls;

public sealed class StatusBadge : Border
{
    private readonly TextBlock _label = new();
    public static readonly DependencyProperty StatusProperty = DependencyProperty.Register(nameof(Status), typeof(PresentationStatus), typeof(StatusBadge), new PropertyMetadata(PresentationStatus.Unavailable, OnStatusChanged));

    public StatusBadge()
    {
        CornerRadius = new CornerRadius(999);
        Padding = new Thickness(8, 3, 8, 3);
        BorderThickness = new Thickness(1);
        Child = _label;
        _label.FontSize = 11;
        _label.FontWeight = FontWeights.SemiBold;
        UpdateVisual();
    }

    public PresentationStatus Status { get => (PresentationStatus)GetValue(StatusProperty); set => SetValue(StatusProperty, value); }
    private static void OnStatusChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((StatusBadge)d).UpdateVisual();

    private void UpdateVisual()
    {
        var descriptor = PresentationStatusCatalog.Describe(Status);
        var brush = TryFindResource(PresentationStatusCatalog.BrushResourceKey(descriptor.Severity)) as System.Windows.Media.Brush ?? System.Windows.Media.Brushes.Gray;
        _label.Text = descriptor.Label;
        _label.Foreground = brush;
        Background = brush is SolidColorBrush solid ? new SolidColorBrush(solid.Color) { Opacity = 0.12 } : System.Windows.Media.Brushes.Transparent;
        BorderBrush = brush;
        ToolTip = descriptor.Label;
        AutomationProperties.SetName(this, $"{descriptor.Label} status");
    }
}
