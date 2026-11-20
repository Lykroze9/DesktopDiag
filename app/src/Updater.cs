// Self-update from GitHub Releases (spec 3.5).
// - Reads the public release list (no account, nothing about the PC is sent).
// - Only tags "app-vX.Y.Z" count (plugin releases use other tags), no drafts or pre-releases.
// - Downloads DesktopDiag.exe + DesktopDiag.exe.sha256 only after the user clicks, checks the
//   SHA-256, renames the running exe to .old, puts the new one in place and restarts it.
// Test hook: DESKTOPDIAG_UPDATE_API may point to http://127.0.0.1:<port>/... (local fake release).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace DesktopDiag
{
    class UpdateInfo
    {
        public string version;
        public string notes;
        public string page;
        public string exeUrl;
        public string shaUrl;
    }

    static class Updater
    {
        const string Api = "https://api.github.com/repos/Lykroze9/DesktopDiag/releases?per_page=30";
        const string ReleasesPage = "https://github.com/Lykroze9/DesktopDiag/releases";

        static string TestApi
        {
            get
            {
                string o = Environment.GetEnvironmentVariable("DESKTOPDIAG_UPDATE_API");
                return o != null && o.StartsWith("http://127.0.0.1:", StringComparison.Ordinal) ? o : null;
            }
        }

        public static string Page { get { return ReleasesPage; } }

        static HttpWebRequest Request(string url)
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
            r.UserAgent = "DesktopDiag-App/" + Program.Version;   // GitHub requires a User-Agent
            r.Accept = "application/vnd.github+json, application/octet-stream, */*";
            r.Timeout = 20000;
            r.ReadWriteTimeout = 60000;
            r.AllowAutoRedirect = true;
            return r;
        }

        static bool AllowedUrl(string url)
        {
            Uri u;
            if (!Uri.TryCreate(url, UriKind.Absolute, out u)) return false;
            if (TestApi != null) return u.Scheme == "http" && u.Host == "127.0.0.1";
            return u.Scheme == "https" && u.Host == "github.com";
        }

        // Newest app release above the running version, or null.
        public static UpdateInfo Check()
        {
            string body;
            using (WebResponse resp = Request(TestApi ?? Api).GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
                body = sr.ReadToEnd();

            JavaScriptSerializer json = new JavaScriptSerializer();
            json.MaxJsonLength = int.MaxValue;
            object[] list = json.DeserializeObject(body) as object[];
            if (list == null) return null;

            Version current = new Version(Program.Version);
            Version best = current;
            UpdateInfo found = null;
            foreach (object o in list)
            {
                Dictionary<string, object> rel = o as Dictionary<string, object>;
                if (rel == null) continue;
                string tag = rel.ContainsKey("tag_name") ? rel["tag_name"] as string : null;
                if (tag == null || !tag.StartsWith("app-v", StringComparison.Ordinal)) continue;
                if (true.Equals(rel.ContainsKey("draft") ? rel["draft"] : null) || true.Equals(rel.ContainsKey("prerelease") ? rel["prerelease"] : null)) continue;
                Version v;
                if (!Version.TryParse(tag.Substring(5), out v) || v <= best) continue;

                string exe = null, sha = null;
                object[] assets = rel.ContainsKey("assets") ? rel["assets"] as object[] : null;
                if (assets != null)
                {
                    foreach (object a in assets)
                    {
                        Dictionary<string, object> asset = a as Dictionary<string, object>;
                        if (asset == null) continue;
                        string name = asset["name"] as string, url = asset["browser_download_url"] as string;
                        if (name == "DesktopDiag.exe") exe = url;
                        if (name == "DesktopDiag.exe.sha256") sha = url;
                    }
                }
                if (exe == null || sha == null || !AllowedUrl(exe) || !AllowedUrl(sha)) continue;
                best = v;
                found = new UpdateInfo();
                found.version = tag.Substring(5);
                found.notes = rel.ContainsKey("body") ? rel["body"] as string : null;
                found.page = rel.ContainsKey("html_url") ? rel["html_url"] as string : ReleasesPage;
                found.exeUrl = exe;
                found.shaUrl = sha;
            }
            return found;
        }

        // Downloads the new exe next to the data folder and checks its SHA-256. Returns its path.
        public static string Download(UpdateInfo u, Action<int> progress)
        {
            string dir = Path.Combine(Program.DataRoot, "update");
            Directory.CreateDirectory(dir);
            string target = Path.Combine(dir, "DesktopDiag-" + u.version + ".exe");
            if (File.Exists(target)) File.Delete(target);

            string shaText;
            using (WebResponse resp = Request(u.shaUrl).GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
                shaText = sr.ReadToEnd().Trim();
            string expected = shaText.Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)[0].ToLowerInvariant();
            if (expected.Length != 64) throw new Exception("Invalid .sha256 file.");

            using (WebResponse resp = Request(u.exeUrl).GetResponse())
            using (Stream s = resp.GetResponseStream())
            using (FileStream f = File.Create(target))
            {
                long total = resp.ContentLength, done = 0;
                byte[] buf = new byte[81920];
                int n, last = -1;
                while ((n = s.Read(buf, 0, buf.Length)) > 0)
                {
                    f.Write(buf, 0, n);
                    done += n;
                    if (total > 0)
                    {
                        int pct = (int)(done * 100 / total);
                        if (pct != last && progress != null) { last = pct; progress(pct); }
                    }
                    if (done > 50L * 1024 * 1024) throw new Exception("Download too large.");
                }
            }

            string actual;
            using (SHA256 h = SHA256.Create())
            using (FileStream f = File.OpenRead(target))
                actual = BitConverter.ToString(h.ComputeHash(f)).Replace("-", "").ToLowerInvariant();
            if (actual != expected)
            {
                try { File.Delete(target); } catch { }
                throw new Exception("SHA-256 mismatch: the downloaded file was discarded.");
            }
            return target;
        }

        // Swaps the running exe for the new one and starts it. The caller then exits.
        public static void Apply(string newExe, bool restart)
        {
            string cur = Application.ExecutablePath;
            string old = cur + ".old";
            if (File.Exists(old)) File.Delete(old);
            File.Move(cur, old);           // allowed while running
            try { File.Copy(newExe, cur); }
            catch { File.Move(old, cur); throw; }
            try { File.Delete(newExe); } catch { }
            if (restart) Process.Start(cur, "--updated");
        }

        // Removes DesktopDiag.exe.old left by an update (the old process may take a moment to exit).
        public static void CleanupOld()
        {
            string old = Application.ExecutablePath + ".old";
            if (!File.Exists(old)) return;
            ThreadPool.QueueUserWorkItem(delegate
            {
                for (int i = 0; i < 20 && File.Exists(old); i++)
                {
                    try { File.Delete(old); } catch { Thread.Sleep(500); }
                }
            });
        }

        // Headless run for tests: DesktopDiag.exe --update-now (log in %LOCALAPPDATA%\DesktopDiag\update.log).
        public static int RunHeadless()
        {
            string log = Path.Combine(Program.DataRoot, "update.log");
            try
            {
                Directory.CreateDirectory(Program.DataRoot);
                UpdateInfo u = Check();
                if (u == null) { File.WriteAllText(log, "up to date " + Program.Version); return 0; }
                string exe = Download(u, null);
                Apply(exe, false);
                File.WriteAllText(log, "updated " + Program.Version + " -> " + u.version);
                return 0;
            }
            catch (Exception ex)
            {
                try { File.WriteAllText(log, "error: " + ex.Message); } catch { }
                return 1;
            }
        }
    }
}
