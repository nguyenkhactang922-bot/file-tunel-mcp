using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using FileMCP.App.Presentation;

namespace FileMCP.App.Controls;

public sealed class InlineNotice : Border
{
    private readonly TextBlock _title = new();
    private readonly TextBlock _message = new();
    public static readonly DependencyProperty FeedbackProperty = DependencyProperty.Register(nameof(Feedback), typeof(PresentationFeedback), typeof(InlineNotice), new PropertyMetadata(null, OnFeedbackChanged));

    public InlineNotice()
    {
        CornerRadius = new CornerRadius(8);
        Padding = new Thickness(12);
        BorderThickness = new Thickness(1);
        _title.FontWeight = FontWeights.SemiBold;
        _message.Margin = new Thickness(0, 3, 0, 0);
        _message.TextWrapping = TextWrapping.Wrap;
        var stack = new StackPanel();
        stack.Children.Add(_title);
        stack.Children.Add(_message);
        Child = stack;
        Render();
    }

    public PresentationFeedback? Feedback { get => (PresentationFeedback?)GetValue(FeedbackProperty); set => SetValue(FeedbackProperty, value); }
    private static void OnFeedbackChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((InlineNotice)d).Render();

    private void Render()
    {
        var feedback = Feedback ?? new PresentationFeedback(PresentationSeverity.Info, "Information", string.Empty);
        _title.Text = feedback.Title;
        _message.Text = feedback.Message;
        var brush = TryFindResource(PresentationStatusCatalog.BrushResourceKey(feedback.Severity)) as System.Windows.Media.Brush ?? System.Windows.Media.Brushes.SteelBlue;
        _title.Foreground = brush;
        _message.Foreground = TryFindResource("FileMcpTextPrimaryBrush") as System.Windows.Media.Brush ?? System.Windows.Media.Brushes.Black;
        BorderBrush = brush;
        Background = brush is SolidColorBrush solid ? new SolidColorBrush(solid.Color) { Opacity = 0.08 } : System.Windows.Media.Brushes.Transparent;
        AutomationProperties.SetName(this, $"{feedback.Title}. {feedback.Message}".Trim());
    }
}
