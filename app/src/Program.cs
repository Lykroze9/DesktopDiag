// DesktopDiag (standalone app) - read-only Windows PC health check, no Claude needed.
// One exe: a WinForms window holding a WebView2 that shows the embedded HTML UI.
// The PowerShell scripts and rules.json are the skill's own files, embedded at build time
// and extracted to %LOCALAPPDATA%\DesktopDiag\app\<version>\ on start.
// Compiled with the .NET Framework 4.8 csc.exe (C# 5): see build.ps1.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace DesktopDiag
{
    static class Program
    {
        public const string Version = "0.1.0";
        public static string DataRoot;   // %LOCALAPPDATA%\DesktopDiag
        public static string BaseDir;    // %LOCALAPPDATA%\DesktopDiag\app\<version>

        [STAThread]
        static void Main()
        {
            DataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DesktopDiag");
            BaseDir = Path.Combine(DataRoot, "app", Version);
            try { ExtractResources(); }
            catch (Exception ex)
            {
                MessageBox.Show("DesktopDiag could not prepare its files:\n" + ex.Message, "DesktopDiag", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            AppDomain.CurrentDomain.AssemblyResolve += ResolveFromBin;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Run();
        }

        // Kept apart so the WebView2 types are only loaded after AssemblyResolve is hooked.
        [MethodImpl(MethodImplOptions.NoInlining)]
        static void Run() { Application.Run(new MainForm()); }

        static Assembly ResolveFromBin(object sender, ResolveEventArgs e)
        {
            string name = new AssemblyName(e.Name).Name;
            string p = Path.Combine(Path.Combine(BaseDir, "bin"), name + ".dll");
            return File.Exists(p) ? Assembly.LoadFrom(p) : null;
        }

        // Resource logical names look like "ui/index.html", "bin/x.dll", "scripts/collect.ps1".
        static void ExtractResources()
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string name in asm.GetManifestResourceNames())
            {
                if (name.IndexOf('/') < 0) continue;
                string target = Path.Combine(BaseDir, name.Replace('/', Path.DirectorySeparatorChar));
                byte[] data;
                using (Stream s = asm.GetManifestResourceStream(name))
                using (MemoryStream ms = new MemoryStream())
                {
                    s.CopyTo(ms);
                    data = ms.ToArray();
                }
                if (File.Exists(target) && SameBytes(File.ReadAllBytes(target), data)) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                try { File.WriteAllBytes(target, data); }
                catch (IOException) { if (!File.Exists(target)) throw; } // DLL in use by another instance
            }
        }

        static bool SameBytes(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
            return true;
        }
    }

    // ------------------------------------------------------------------ settings
    class Settings
    {
        public string lang;      // "fr" | "en"
        public string theme;     // "system" | "light" | "dark" | "contrast"
        public int textSize;     // 100 | 125 | 150

        static string FilePath { get { return Path.Combine(Program.DataRoot, "app-settings.json"); } }

        public static Settings Load()
        {
            Settings s = null;
            try { if (File.Exists(FilePath)) s = new JavaScriptSerializer().Deserialize<Settings>(File.ReadAllText(FilePath, Encoding.UTF8)); }
            catch { }
            if (s == null) s = new Settings();
            if (s.lang != "fr" && s.lang != "en")
                s.lang = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr" ? "fr" : "en";
            if (s.theme != "light" && s.theme != "dark" && s.theme != "contrast") s.theme = "system";
            if (s.textSize != 125 && s.textSize != 150) s.textSize = 100;
            return s;
        }

        public void Save()
        {
            Directory.CreateDirectory(Program.DataRoot);
            File.WriteAllText(FilePath, new JavaScriptSerializer().Serialize(this), new UTF8Encoding(false));
        }
    }

    // ------------------------------------------------------------------ PowerShell runner
    static class Ps
    {
        public static string ScriptsDir { get { return Path.Combine(Program.BaseDir, "scripts"); } }
        public static string HistoryDir { get { return Path.Combine(Program.DataRoot, "history"); } }

        static string Q(string s) { return "'" + s.Replace("'", "''") + "'"; }

        // Runs a bundled script and returns its stdout (UTF-8). Throws on failure.
        public static string Run(string script, string args)
        {
            string path = Path.Combine(ScriptsDir, script);
            string cmd = "[Console]::OutputEncoding=[Text.Encoding]::UTF8; & " + Q(path) + (string.IsNullOrEmpty(args) ? "" : " " + args);
            ProcessStartInfo psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"" + cmd + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;
            StringBuilder err = new StringBuilder();
            using (Process p = new Process())
            {
                p.StartInfo = psi;
                p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { if (e.Data != null) err.AppendLine(e.Data); };
                p.Start();
                p.BeginErrorReadLine();
                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit();
                if (p.ExitCode != 0 && output.Trim().Length == 0)
                    throw new Exception(script + " failed (" + p.ExitCode + "): " + err.ToString().Trim());
                return output;
            }
        }

        public static string Arg(string value) { return Q(value); }

        // Newest non-admin snapshot in the shared history (same folder as the skill).
        public static List<string> History()
        {
            List<string> list = new List<string>();
            if (!Directory.Exists(HistoryDir)) return list;
            foreach (string f in Directory.GetFiles(HistoryDir, "*.json"))
                if (!f.EndsWith("-admin.json", StringComparison.OrdinalIgnoreCase)) list.Add(f);
            list.Sort(StringComparer.OrdinalIgnoreCase);
            list.Reverse();
            return list;
        }

        public static bool IsHistoryFile(string path)
        {
            try
            {
                string full = Path.GetFullPath(path);
                return full.StartsWith(Path.GetFullPath(HistoryDir) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
                    && full.EndsWith(".json", StringComparison.OrdinalIgnoreCase) && File.Exists(full);
            }
            catch { return false; }
        }
    }

    // ------------------------------------------------------------------ window
    class MainForm : Form
    {
        const string Host = "app.desktopdiag";
        Microsoft.Web.WebView2.WinForms.WebView2 web;
        Settings settings;
        readonly JavaScriptSerializer json = new JavaScriptSerializer();
        int busy; // 1 while a check runs

        [DllImport("dwmapi.dll")]
        static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        public MainForm()
        {
            json.MaxJsonLength = int.MaxValue;
            settings = Settings.Load();
            Text = "DesktopDiag";
            ClientSize = new Size(1000, 740);
            MinimumSize = new Size(720, 560);
            StartPosition = FormStartPosition.CenterScreen;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            bool dark = WantsDark();
            BackColor = dark ? Color.FromArgb(0x1b, 0x1b, 0x1f) : Color.FromArgb(0xf7, 0xf7, 0xf8);

            web = new Microsoft.Web.WebView2.WinForms.WebView2();
            web.Dock = DockStyle.Fill;
            web.DefaultBackgroundColor = BackColor;
            Controls.Add(web);
            HandleCreated += delegate { SetDarkTitleBar(dark); };
            Load += OnLoad;
        }

        bool WantsDark()
        {
            if (settings.theme == "dark") return true;
            if (settings.theme == "light" || settings.theme == "contrast") return false;
            try
            {
                object v = Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1);
                return v is int && (int)v == 0;
            }
            catch { return false; }
        }

        void SetDarkTitleBar(bool dark)
        {
            int v = dark ? 1 : 0;
            try { DwmSetWindowAttribute(Handle, 20, ref v, 4); } catch { }
        }

        async void OnLoad(object sender, EventArgs e)
        {
            try
            {
                Microsoft.Web.WebView2.Core.CoreWebView2Environment.SetLoaderDllFolderPath(Path.Combine(Program.BaseDir, "bin"));
                var env = await Microsoft.Web.WebView2.Core.CoreWebView2Environment.CreateAsync(null, Path.Combine(Program.DataRoot, "WebView2"), null);
                await web.EnsureCoreWebView2Async(env);
            }
            catch (Exception ex)
            {
                MissingRuntime(ex);
                return;
            }
            var core = web.CoreWebView2;
            bool dev = Environment.GetEnvironmentVariable("DESKTOPDIAG_DEVTOOLS") == "1";
            core.Settings.AreDevToolsEnabled = dev;
            core.Settings.AreDefaultContextMenusEnabled = dev;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.IsZoomControlEnabled = false;
            core.Settings.AreBrowserAcceleratorKeysEnabled = dev;
            core.SetVirtualHostNameToFolderMapping(Host, Path.Combine(Program.BaseDir, "ui"),
                Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind.DenyCors);
            core.NavigationStarting += delegate(object s, Microsoft.Web.WebView2.Core.CoreWebView2NavigationStartingEventArgs a)
            {
                if (!a.Uri.StartsWith("https://" + Host + "/", StringComparison.OrdinalIgnoreCase)) a.Cancel = true;
            };
            core.NewWindowRequested += delegate(object s, Microsoft.Web.WebView2.Core.CoreWebView2NewWindowRequestedEventArgs a) { a.Handled = true; };
            core.WebMessageReceived += OnMessage;
            web.Source = new Uri("https://" + Host + "/index.html");
        }

        void MissingRuntime(Exception ex)
        {
            bool fr = settings.lang == "fr";
            string msg = fr
                ? "DesktopDiag a besoin du composant Microsoft Edge WebView2, absent de ce PC.\n\nVoulez-vous ouvrir la page de téléchargement de Microsoft ?\n\n(" + ex.Message + ")"
                : "DesktopDiag needs the Microsoft Edge WebView2 component, which is missing on this PC.\n\nOpen Microsoft's download page?\n\n(" + ex.Message + ")";
            if (MessageBox.Show(msg, "DesktopDiag", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) == DialogResult.Yes)
                Process.Start("https://developer.microsoft.com/microsoft-edge/webview2/");
            Close();
        }

        // ---------------------------------------------------------- page <-> app messages
        void Send(Dictionary<string, object> msg) { SendRaw(json.Serialize(msg)); }

        void SendRaw(string rawJson)
        {
            if (IsDisposed) return;
            if (InvokeRequired) { BeginInvoke(new Action<string>(SendRaw), rawJson); return; }
            if (web.CoreWebView2 != null) web.CoreWebView2.PostWebMessageAsJson(rawJson);
        }

        static Dictionary<string, object> Msg(string type)
        {
            Dictionary<string, object> d = new Dictionary<string, object>();
            d["type"] = type;
            return d;
        }

        void OnMessage(object sender, Microsoft.Web.WebView2.Core.CoreWebView2WebMessageReceivedEventArgs e)
        {
            if (!e.Source.StartsWith("https://" + Host + "/", StringComparison.OrdinalIgnoreCase)) return;
            Dictionary<string, object> m;
            try { m = json.Deserialize<Dictionary<string, object>>(e.WebMessageAsJson); }
            catch { return; }
            object t;
            if (m == null || !m.TryGetValue("type", out t)) return;
            switch (t as string)
            {
                case "init": SendInit(); break;
                case "saveSettings": SaveSettings(m); break;
                case "runCheck": RunCheck(); break;
                case "score": Score(Get(m, "path"), Get(m, "id")); break;
                case "open": OpenTarget(Get(m, "target")); break;
            }
        }

        // "Ouvrir pour moi": fixed list of Windows screens. They only open; nothing is changed.
        static readonly Dictionary<string, string[]> OpenTargets = new Dictionary<string, string[]>
        {
            { "reliability",   new[] { "perfmon.exe", "/rel" } },
            { "devmgmt",       new[] { "devmgmt.msc", "" } },
            { "storage",       new[] { "ms-settings:storagesense", "" } },
            { "cleanmgr",      new[] { "cleanmgr.exe", "" } },
            { "apps",          new[] { "ms-settings:appsfeatures", "" } },
            { "security",      new[] { "windowsdefender:", "" } },
            { "firewall",      new[] { "windowsdefender://network", "" } },
            { "windowsupdate", new[] { "ms-settings:windowsupdate", "" } },
            { "uac",           new[] { "UserAccountControlSettings.exe", "" } },
            { "taskmgr",       new[] { "taskmgr.exe", "" } },
            { "startup",       new[] { "ms-settings:startupapps", "" } },
            { "memdiag",       new[] { "mdsched.exe", "" } },
            { "power",         new[] { "ms-settings:powersleep", "" } },
            { "network",       new[] { "ms-settings:network-status", "" } },
            { "wifi",          new[] { "ms-settings:network-wifi", "" } },
            { "battery",       new[] { "ms-settings:batterysaver", "" } },
            { "backup",        new[] { "ms-settings:backup", "" } }
        };

        void OpenTarget(string key)
        {
            string[] t;
            if (key == null || !OpenTargets.TryGetValue(key, out t)) return;
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(t[0], t[1]);
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                Dictionary<string, object> d = Msg("openFailed");
                d["target"] = key;
                d["message"] = ex.Message;
                Send(d);
            }
        }

        static string Get(Dictionary<string, object> m, string key)
        {
            object v;
            return m.TryGetValue(key, out v) && v != null ? Convert.ToString(v, CultureInfo.InvariantCulture) : null;
        }

        void SendInit()
        {
            Dictionary<string, object> d = Msg("init");
            d["version"] = Program.Version;
            d["settings"] = settings;
            List<Dictionary<string, object>> hist = new List<Dictionary<string, object>>();
            foreach (string f in Ps.History())
            {
                Dictionary<string, object> h = new Dictionary<string, object>();
                h["path"] = f;
                h["name"] = Path.GetFileNameWithoutExtension(f);
                hist.Add(h);
            }
            d["history"] = hist;
            Send(d);
        }

        void SaveSettings(Dictionary<string, object> m)
        {
            string lang = Get(m, "lang"), theme = Get(m, "theme"), size = Get(m, "textSize");
            if (lang == "fr" || lang == "en") settings.lang = lang;
            if (theme == "system" || theme == "light" || theme == "dark" || theme == "contrast") settings.theme = theme;
            int ts;
            if (int.TryParse(size, out ts) && (ts == 100 || ts == 125 || ts == 150)) settings.textSize = ts;
            try { settings.Save(); } catch { }
            string dark = Get(m, "dark");
            if (dark != null) SetDarkTitleBar(dark == "True" || dark == "true");
        }

        void RunCheck()
        {
            if (Interlocked.Exchange(ref busy, 1) == 1) return;
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    Stopwatch sw = Stopwatch.StartNew();
                    string output = Ps.Run("collect.ps1", null);
                    string snap = null;
                    foreach (string line in output.Split('\n'))
                    {
                        string l = line.Trim();
                        if (l.EndsWith(".json", StringComparison.OrdinalIgnoreCase) && Ps.IsHistoryFile(l)) { snap = l; break; }
                    }
                    if (snap == null) throw new Exception("collect.ps1: no snapshot written.\n" + output.Trim());
                    Dictionary<string, object> d = Msg("checkDone");
                    d["path"] = snap;
                    d["seconds"] = Math.Round(sw.Elapsed.TotalSeconds);
                    Send(d);
                }
                catch (Exception ex)
                {
                    Dictionary<string, object> d = Msg("error");
                    d["where"] = "collect";
                    d["message"] = ex.Message;
                    Send(d);
                }
                finally { Interlocked.Exchange(ref busy, 0); }
            });
        }

        // Scores a history snapshot with the skill's score.ps1 (rules.json) in the UI language.
        void Score(string path, string id)
        {
            string lang = settings.lang;
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    if (path == null || !Ps.IsHistoryFile(path)) throw new Exception("Unknown snapshot.");
                    string raw = Ps.Run("score.ps1", "-Path " + Ps.Arg(path) + " -Lang " + lang).Trim();
                    int start = raw.IndexOf('{');
                    if (start < 0) throw new Exception("score.ps1: no result.\n" + raw);
                    raw = raw.Substring(start);
                    json.DeserializeObject(raw); // validates before passing it on untouched
                    SendRaw("{\"type\":\"score\",\"id\":" + json.Serialize(id) + ",\"path\":" + json.Serialize(path) + ",\"data\":" + raw + "}");
                }
                catch (Exception ex)
                {
                    Dictionary<string, object> d = Msg("error");
                    d["where"] = "score";
                    d["id"] = id;
                    d["message"] = ex.Message;
                    Send(d);
                }
            });
        }
    }
}
