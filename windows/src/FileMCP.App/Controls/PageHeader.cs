using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using FileMCP.App.Presentation;

namespace FileMCP.App.Controls;

public sealed class PageHeader : Grid
{
    private readonly TextBlock _title = new();
    private readonly TextBlock _description = new();
    private readonly StatusBadge _status = new();

    public PageHeader()
    {
        ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var text = new StackPanel();
        _title.FontSize = 26; _title.FontWeight = FontWeights.SemiBold;
        _description.Margin = new Thickness(0, 3, 0, 0); _description.TextWrapping = TextWrapping.Wrap;
        text.Children.Add(_title); text.Children.Add(_description);
        Children.Add(text); Grid.SetColumn(_status, 1); Children.Add(_status);
        Refresh();
    }

    public string Title { get => (string)GetValue(TitleProperty); set => SetValue(TitleProperty, value); }
    public string Description { get => (string)GetValue(DescriptionProperty); set => SetValue(DescriptionProperty, value); }
    public PresentationStatus Status { get => (PresentationStatus)GetValue(StatusProperty); set => SetValue(StatusProperty, value); }
    public bool ShowStatus { get => (bool)GetValue(ShowStatusProperty); set => SetValue(ShowStatusProperty, value); }

    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(nameof(Title), typeof(string), typeof(PageHeader), new PropertyMetadata(string.Empty, OnChanged));
    public static readonly DependencyProperty DescriptionProperty = DependencyProperty.Register(nameof(Description), typeof(string), typeof(PageHeader), new PropertyMetadata(string.Empty, OnChanged));
    public static readonly DependencyProperty StatusProperty = DependencyProperty.Register(nameof(Status), typeof(PresentationStatus), typeof(PageHeader), new PropertyMetadata(PresentationStatus.Unavailable, OnChanged));
    public static readonly DependencyProperty ShowStatusProperty = DependencyProperty.Register(nameof(ShowStatus), typeof(bool), typeof(PageHeader), new PropertyMetadata(false, OnChanged));
    private static void OnChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((PageHeader)d).Refresh();

    private void Refresh()
    {
        _title.Text = Title; _description.Text = Description;
        _description.Visibility = string.IsNullOrWhiteSpace(Description) ? Visibility.Collapsed : Visibility.Visible;
        _status.Status = Status; _status.Visibility = ShowStatus ? Visibility.Visible : Visibility.Collapsed;
        AutomationProperties.SetName(this, Title);
    }
}
