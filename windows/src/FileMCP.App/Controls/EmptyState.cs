using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;

namespace FileMCP.App.Controls;

public sealed class EmptyState : StackPanel
{
    private readonly TextBlock _title = new();
    private readonly TextBlock _message = new();
    private readonly System.Windows.Controls.Button _action = new();

    public EmptyState()
    {
        HorizontalAlignment = System.Windows.HorizontalAlignment.Center;
        VerticalAlignment = VerticalAlignment.Center;
        MaxWidth = 440;
        _title.FontSize = 18;
        _title.FontWeight = FontWeights.SemiBold;
        _title.TextAlignment = TextAlignment.Center;
        _message.Margin = new Thickness(0, 6, 0, 12);
        _message.TextWrapping = TextWrapping.Wrap;
        _message.TextAlignment = TextAlignment.Center;
        _action.HorizontalAlignment = System.Windows.HorizontalAlignment.Center;
        Children.Add(_title); Children.Add(_message); Children.Add(_action);
        Refresh();
    }

    public string Title { get => (string)GetValue(TitleProperty); set => SetValue(TitleProperty, value); }
    public string Message { get => (string)GetValue(MessageProperty); set => SetValue(MessageProperty, value); }
    public string? ActionLabel { get => (string?)GetValue(ActionLabelProperty); set => SetValue(ActionLabelProperty, value); }
    public event RoutedEventHandler? ActionRequested { add => _action.Click += value; remove => _action.Click -= value; }

    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(nameof(Title), typeof(string), typeof(EmptyState), new PropertyMetadata("Nothing here yet", OnChanged));
    public static readonly DependencyProperty MessageProperty = DependencyProperty.Register(nameof(Message), typeof(string), typeof(EmptyState), new PropertyMetadata(string.Empty, OnChanged));
    public static readonly DependencyProperty ActionLabelProperty = DependencyProperty.Register(nameof(ActionLabel), typeof(string), typeof(EmptyState), new PropertyMetadata(null, OnChanged));
    private static void OnChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((EmptyState)d).Refresh();

    private void Refresh()
    {
        _title.Text = Title; _message.Text = Message; _action.Content = ActionLabel ?? string.Empty;
        _action.Visibility = string.IsNullOrWhiteSpace(ActionLabel) ? Visibility.Collapsed : Visibility.Visible;
        AutomationProperties.SetName(this, $"{Title}. {Message}".Trim());
    }
}
