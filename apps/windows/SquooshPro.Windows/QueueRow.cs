using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace SquooshPro.Windows;

internal sealed class QueueRow : Grid
{
    public WorkspaceItem Item { get; }
    private readonly Image thumbnail;
    private readonly TextBlock status;

    public QueueRow(WorkspaceItem item)
    {
        Item = item;
        Height = 64;
        Padding = new Thickness(4, 6, 4, 6);
        ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(52) });
        ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        thumbnail = new Image { Width = 44, Height = 44, Stretch = Stretch.UniformToFill };
        thumbnail.Source = item.Thumbnail;
        SetColumn(thumbnail, 0);
        Children.Add(thumbnail);
        var copy = new StackPanel { Spacing = 3, VerticalAlignment = VerticalAlignment.Center };
        copy.Children.Add(new TextBlock { Text = item.FileName, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
        status = new TextBlock { Text = item.StatusText, FontSize = 12, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray), TextTrimming = TextTrimming.CharacterEllipsis };
        copy.Children.Add(status);
        SetColumn(copy, 1);
        Children.Add(copy);
        AutomationProperties.SetName(this, $"{item.FileName}，{item.StatusText}");
        AutomationProperties.SetAutomationId(this, $"queue.item.{item.Id:D}");
    }

    public void Refresh()
    {
        thumbnail.Source = Item.Thumbnail;
        status.Text = Item.StatusText;
        status.Foreground = Item.State == SquooshPro.Core.FileState.failed
            ? new SolidColorBrush(Microsoft.UI.Colors.Firebrick)
            : Item.IsCached ? new SolidColorBrush(Microsoft.UI.Colors.Teal) : new SolidColorBrush(Microsoft.UI.Colors.Gray);
        AutomationProperties.SetName(this, $"{Item.FileName}，{Item.StatusText}");
    }
}
