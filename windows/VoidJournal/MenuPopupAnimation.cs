using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace VoidJournal;

// Keep the framework's MenuItem template, popup placement, focus and navigation.
// Replace only Fluent's large entrance translation, which also redraws its shadow.
internal sealed class MenuPopupAnimation
{
    private readonly MenuItem item;
    private Popup? popup;
    private FrameworkElement? animatedBorder;
    private CacheMode? originalCacheMode;
    private int generation;

    private MenuPopupAnimation(MenuItem item)
    {
        this.item = item;
        item.Loaded += (_, _) => ConnectPopup();
        item.SubmenuOpened += (_, e) =>
        {
            if (ReferenceEquals(e.OriginalSource, item)) ConnectPopup();
        };
    }

    public static void Attach(Menu menu)
    {
        foreach (var item in menu.Items.OfType<MenuItem>()) _ = new MenuPopupAnimation(item);
    }

    private void ConnectPopup()
    {
        var next = item.Template?.FindName("PART_Popup", item) as Popup;
        if (ReferenceEquals(next, popup)) return;
        ResetAnimation();
        if (popup != null)
        {
            popup.Opened -= OnOpened;
            popup.Closed -= OnClosed;
        }
        popup = next;
        if (popup != null)
        {
            popup.Opened += OnOpened;
            popup.Closed += OnClosed;
        }
    }

    private void OnOpened(object? sender, EventArgs e)
    {
        ResetAnimation();
        if (item.Template?.FindName("SubmenuBorder", item) is not FrameworkElement border) return;
        animatedBorder = border;
        originalCacheMode = border.CacheMode;
        int currentGeneration = ++generation;
        // Popup.Opened can run before the template's IsSubmenuOpen storyboard starts.
        // Keep that first state invisible, then replace its clock before the render pass.
        border.BeginAnimation(UIElement.OpacityProperty, new DoubleAnimation(0, 0, TimeSpan.Zero));
        item.Dispatcher.BeginInvoke(DispatcherPriority.Normal, () =>
        {
            if (generation != currentGeneration || popup?.IsOpen != true) return;
            StartAnimation(border, currentGeneration);
        });
    }

    private void StartAnimation(FrameworkElement border, int currentGeneration)
    {
        if (border.RenderTransform is not TranslateTransform translation) { ResetAnimation(); return; }
        if (translation.IsFrozen)
        {
            translation = translation.Clone();
            border.RenderTransform = translation;
        }
        // SnapshotAndReplace removes the template's clock instead of composing with it.
        translation.BeginAnimation(TranslateTransform.YProperty, null);
        translation.Y = 0;
        if (!SystemParameters.ClientAreaAnimation || SystemParameters.HighContrast) { ResetAnimation(); return; }
        border.CacheMode = new BitmapCache { SnapsToDevicePixels = true };
        var duration = TimeSpan.FromMilliseconds(160);
        var easing = new CubicEase { EasingMode = EasingMode.EaseOut };
        var fade = new DoubleAnimation(0, 1, duration) { EasingFunction = easing };
        fade.Completed += (_, _) =>
        {
            if (generation == currentGeneration) ResetAnimation();
        };
        translation.BeginAnimation(TranslateTransform.YProperty,
            new DoubleAnimation(-6, 0, duration) { EasingFunction = easing });
        border.BeginAnimation(UIElement.OpacityProperty, fade);
    }

    private void OnClosed(object? sender, EventArgs e) => ResetAnimation();

    private void ResetAnimation()
    {
        generation++;
        if (animatedBorder == null) return;
        animatedBorder.BeginAnimation(UIElement.OpacityProperty, null);
        if (animatedBorder.RenderTransform is TranslateTransform translation && !translation.IsFrozen)
            translation.BeginAnimation(TranslateTransform.YProperty, null);
        animatedBorder.CacheMode = originalCacheMode;
        animatedBorder = null;
        originalCacheMode = null;
    }
}
