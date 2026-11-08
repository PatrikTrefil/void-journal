using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace VoidJournal;

public partial class MainWindow : Window
{
    private readonly Preferences preferences = Preferences.Load();
    private readonly Stopwatch clock = Stopwatch.StartNew();
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromMilliseconds(250) };
    private TimeSpan lastRenderingTime = TimeSpan.MinValue;
    private double lastActiveFrame = -10;
    private bool NeedsAnimationFrames => introducing || Surface.Engine.Glyphs.Count > 0 || clock.Elapsed.TotalSeconds - lastActiveFrame < 1.5;
    private bool composing, clearing, introducing, fullScreen;
    private WindowState previousState;
    private double lastFrame, introTime;
    private int introIndex;
    private const string Demo = "Some thoughts just need somewhere to go. Write them down. Watch them drift away.";

    public MainWindow()
    {
        InitializeComponent();
        Surface.Preferences = preferences;
        ApplyPreferences();
        Input.TextChanged += (_, _) => { if (!clearing && !composing) Dispatcher.BeginInvoke(DispatcherPriority.Background, CommitInput); };
        TextCompositionManager.AddPreviewTextInputStartHandler(Input, (_, _) =>
        {
            composing = true;
            Input.SetResourceReference(Control.ForegroundProperty, SystemColors.WindowTextBrushKey);
        });
        TextCompositionManager.AddPreviewTextInputHandler(Input, (_, _) =>
        {
            composing = false;
            Input.Foreground = Brushes.Transparent;
            Dispatcher.BeginInvoke(DispatcherPriority.Background, CommitInput);
        });
        PreviewKeyDown += OnKeyDown;
        WritingArea.MouseDown += (_, _) => { if (!introducing) Input.Focus(); };
        timer.Tick += (_, _) => { if (WindowState == WindowState.Minimized || !NeedsAnimationFrames) Frame(); };
        CompositionTarget.Rendering += OnRendering;
        Loaded += (_, _) =>
        {
            timer.Start();
            if (!preferences.HasSeenIntro) ShowIntro();
            else Input.Focus();
        };
        Closed += (_, _) => { CompositionTarget.Rendering -= OnRendering; timer.Stop(); Surface.Engine.Reset(); Input.Clear(); };
    }

    private void CommitInput()
    {
        if (composing || clearing || Input.Text.Length == 0) return;
        if (!introducing) Surface.Engine.Insert(Input.Text);
        clearing = true;
        Input.Clear(); // Also prevents native undo or clipboard commands from retaining a journal history.
        clearing = false;
    }

    private void OnRendering(object? sender, EventArgs args)
    {
        if (args is not RenderingEventArgs rendering || rendering.RenderingTime == lastRenderingTime) return;
        lastRenderingTime = rendering.RenderingTime;
        if (WindowState != WindowState.Minimized && NeedsAnimationFrames) Frame();
    }

    private void Frame()
    {
        double now = clock.Elapsed.TotalSeconds;
        if (introducing || Surface.Engine.Glyphs.Count > 0) lastActiveFrame = now;
        if (introducing)
        {
            if (introIndex < Demo.Length && now - introTime > .055)
            {
                Surface.Engine.Insert(Demo[introIndex++].ToString());
                introTime = now;
            }
            else if (introIndex == Demo.Length && now - introTime > 1.8)
            {
                Surface.Engine.ReleaseAll(now);
                introIndex++;
                IntroCard.Visibility = Visibility.Visible;
            }
        }
        Surface.FrameDelta = now - lastFrame;
        Surface.Now = now;
        Surface.Engine.Tick(now, now - lastFrame);
        lastFrame = now;
        Surface.InvalidateVisual();
        Input.Width = Math.Clamp(WritingArea.ActualWidth - Surface.Caret.X - 16, 40, 320);
        Canvas.SetLeft(Input, Surface.Caret.X);
        Canvas.SetTop(Input, Surface.Caret.Y);
    }

    private void ApplyPreferences()
    {
        Application.Current.ThemeMode = preferences.Appearance switch
        {
            "Dark" => ThemeMode.Dark,
            "Light" => ThemeMode.Light,
            _ => ThemeMode.System
        };
        Surface.Engine.FadeDuration = preferences.Theme == "Void" ? 2.8 : 2;
        Input.FontSize = preferences.TextSize;
        Input.FontFamily = Surface.JournalFont;
        Surface.ClearTextCache();
        Surface.InvalidateVisual();
    }

    private void SavePreferences()
    {
        ApplyPreferences();
        if (!preferences.Save()) MessageBox.Show(this, "Your settings could not be saved. They will apply for this session.", "Void Journal", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void OnKeyDown(object sender, KeyEventArgs e)
    {
        if (composing) return;
        bool ctrl = Keyboard.Modifiers.HasFlag(ModifierKeys.Control);
        if (e.Key == Key.F11) { ToggleFullScreen(); e.Handled = true; }
        else if (e.Key == Key.Escape && fullScreen) { ToggleFullScreen(); e.Handled = true; }
        else if (ctrl && e.Key == Key.OemComma) { OpenSettings(); e.Handled = true; }
        else if (!introducing && (Input.IsKeyboardFocusWithin || ctrl))
        {
            if (ctrl && e.Key == Key.Enter) Surface.Engine.ReleaseAll(clock.Elapsed.TotalSeconds);
            else if (ctrl && e.Key is Key.D1 or Key.D2) { preferences.Theme = e.Key == Key.D1 ? "Void" : "Dissolve"; SavePreferences(); }
            else if (ctrl && e.Key is Key.OemPlus or Key.Add) ResizeText(1);
            else if (ctrl && e.Key is Key.OemMinus or Key.Subtract) ResizeText(-1);
            else if (ctrl && e.Key == Key.D0) { preferences.TextSize = 28; SavePreferences(); }
            else if (e.Key == Key.Back) Surface.Engine.Backspace(ctrl);
            else if (e.Key is Key.Left or Key.Right or Key.Up or Key.Down or Key.Home or Key.End or Key.PageUp or Key.PageDown or Key.Delete || (ctrl && e.Key is Key.A or Key.X or Key.C or Key.Z or Key.Y)) { }
            else return; // Native TextBox handles text, dead keys, IME, Enter and paste.
            e.Handled = true;
        }
    }

    private void ResizeText(int delta)
    {
        int[] sizes = [18, 22, 28, 34];
        preferences.TextSize = sizes[Math.Clamp(Array.IndexOf(sizes, preferences.TextSize) + delta, 0, 3)];
        SavePreferences();
    }

    private void ToggleFullScreen()
    {
        if (!fullScreen)
        {
            previousState = WindowState;
            WindowState = WindowState.Normal;
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = WindowState.Maximized;
        }
        else
        {
            WindowState = WindowState.Normal;
            WindowStyle = WindowStyle.SingleBorderWindow;
            ResizeMode = ResizeMode.CanResize;
            WindowState = previousState;
        }
        fullScreen = !fullScreen;
    }

    private void ShowIntro()
    {
        Surface.Engine.Reset();
        Surface.Engine.AutoRelease = false;
        introducing = true;
        introIndex = 0;
        introTime = clock.Elapsed.TotalSeconds;
        Input.IsEnabled = false;
        IntroCard.Visibility = Visibility.Visible; // Can skip the demonstration with keyboard or mouse.
        IntroTheme.SelectedIndex = preferences.Theme == "Void" ? 0 : 1;
        IntroTheme.Focus();
    }
    private void FinishIntro(bool enterFullScreen)
    {
        preferences.Theme = IntroTheme.SelectedIndex == 0 ? "Void" : "Dissolve";
        preferences.HasSeenIntro = true;
        SavePreferences();
        Surface.Engine.Reset();
        Surface.Engine.AutoRelease = true;
        introducing = false;
        IntroCard.Visibility = Visibility.Collapsed;
        Input.IsEnabled = true;
        if (enterFullScreen && !fullScreen) ToggleFullScreen();
        Input.Focus();
    }

    private void OpenSettings()
    {
        new SettingsWindow(preferences, SavePreferences) { Owner = this }.ShowDialog();
        if (!introducing) Input.Focus();
    }
    private void ReleaseClick(object sender, RoutedEventArgs e) { if (!introducing) Surface.Engine.ReleaseAll(clock.Elapsed.TotalSeconds); }
    private void SettingsClick(object sender, RoutedEventArgs e) => OpenSettings();
    private void ExitClick(object sender, RoutedEventArgs e) => Close();
    private void VoidClick(object sender, RoutedEventArgs e) { preferences.Theme = "Void"; SavePreferences(); }
    private void DissolveClick(object sender, RoutedEventArgs e) { preferences.Theme = "Dissolve"; SavePreferences(); }
    private void BiggerClick(object sender, RoutedEventArgs e) => ResizeText(1);
    private void SmallerClick(object sender, RoutedEventArgs e) => ResizeText(-1);
    private void DefaultSizeClick(object sender, RoutedEventArgs e) { preferences.TextSize = 28; SavePreferences(); }
    private void FullScreenClick(object sender, RoutedEventArgs e) => ToggleFullScreen();
    private void IntroClick(object sender, RoutedEventArgs e) => ShowIntro();
    private void StartClick(object sender, RoutedEventArgs e) => FinishIntro(false);
    private void StartFullScreenClick(object sender, RoutedEventArgs e) => FinishIntro(true);
}
