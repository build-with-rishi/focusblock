using System.Windows;
using System.Windows.Controls;

namespace FocusBlock;

/// <summary>
/// Minimal WPF text-input dialog (prompt + text box + OK/Cancel), used for
/// "Set Calendar URL…". Returns true from ShowDialog() if OK was pressed.
/// </summary>
public sealed class InputDialog : Window
{
    private readonly TextBox _textBox;

    public string Value => _textBox.Text;

    public InputDialog(string title, string prompt, string initialValue)
    {
        Title = title;
        Width = 560;
        SizeToContent = SizeToContent.Height;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;

        var panel = new StackPanel { Margin = new Thickness(16) };

        panel.Children.Add(new TextBlock
        {
            Text = prompt,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 10)
        });

        _textBox = new TextBox
        {
            Text = initialValue,
            Margin = new Thickness(0, 0, 0, 14)
        };
        panel.Children.Add(_textBox);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };

        var okButton = new Button
        {
            Content = "OK",
            Width = 80,
            Margin = new Thickness(0, 0, 8, 0),
            IsDefault = true
        };
        okButton.Click += (_, _) => DialogResult = true;

        var cancelButton = new Button
        {
            Content = "Cancel",
            Width = 80,
            IsCancel = true
        };

        buttons.Children.Add(okButton);
        buttons.Children.Add(cancelButton);
        panel.Children.Add(buttons);

        Content = panel;

        Loaded += (_, _) =>
        {
            _textBox.SelectAll();
            _textBox.Focus();
        };
    }
}
