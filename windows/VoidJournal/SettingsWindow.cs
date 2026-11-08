using System.Windows;
using System.Windows.Controls;

namespace VoidJournal;

public sealed class SettingsWindow : Window
{
    public SettingsWindow(Preferences p, Action changed)
    {
        Title = "Settings — Void Journal";
        Width = 420;
        SizeToContent = SizeToContent.Height;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var panel = new StackPanel { Margin = new Thickness(28) };
        Content = panel;
        AddPicker("Theme", ["Void", "Dissolve"], p.Theme, value => p.Theme = value);
        AddPicker("Appearance", ["System", "Light", "Dark"], p.Appearance, value => p.Appearance = value);
        AddPicker("Typeface", ["Serif", "Sans Serif", "Monospaced"], p.Typeface, value => p.Typeface = value);
        AddPicker("Text size", ["18", "22", "28", "34"], p.TextSize.ToString(), value => p.TextSize = int.Parse(value));
        var moving = new CheckBox { Content = "Moving gradients", IsChecked = p.MovingGradients, Margin = new Thickness(0, 8, 0, 20) };
        moving.Click += (_, _) => { p.MovingGradients = moving.IsChecked == true; changed(); };
        panel.Children.Add(moving);
        panel.Children.Add(new TextBlock { Text = "Windows animation settings are respected.\nOnly preferences are saved. Your writing never is.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 20) });
        var close = new Button { Content = "Close", IsCancel = true, HorizontalAlignment = HorizontalAlignment.Right, Padding = new Thickness(24, 8, 24, 8) };
        close.Click += (_, _) => Close();
        panel.Children.Add(close);

        void AddPicker(string name, string[] values, string selected, Action<string> set)
        {
            var label = new Label { Content = name, Padding = new Thickness(0, 0, 0, 6) };
            var picker = new ComboBox { ItemsSource = values, SelectedItem = selected, Margin = new Thickness(0, 0, 0, 16) };
            System.Windows.Automation.AutomationProperties.SetName(picker, name);
            label.Target = picker;
            picker.SelectionChanged += (_, _) => { if (picker.SelectedItem is string value) { set(value); changed(); } };
            panel.Children.Add(label);
            panel.Children.Add(picker);
        }
    }
}
