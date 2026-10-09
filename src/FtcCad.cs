// FTC_CAD - aplicativo do catalogo de pecas STEP (goBILDA, REV, AndyMark).
// Um unico .exe: abre o catalogo, atualiza sozinho, baixa pecas sob demanda e cuida das pecas da equipe.
// Janelas nativas do Windows (sem terminal, sem PowerShell).
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace FtcCad
{
    // ------------------------------------------------------------------ tema
    static class Tema
    {
        public static readonly Color Fundo = Color.FromArgb(19, 14, 34);
        public static readonly Color Campo = Color.FromArgb(30, 22, 55);
        public static readonly Color Texto = Color.FromArgb(236, 230, 250);
        public static readonly Color Suave = Color.FromArgb(170, 160, 200);
        public static readonly Color Titulo = Color.FromArgb(182, 146, 246);
        public static readonly Color Botao = Color.FromArgb(124, 58, 237);
        public static readonly Color BotaoCinza = Color.FromArgb(60, 48, 92);

        public static Form Janela(string titulo, int w, int h)
        {
            Form f = new Form();
            f.AutoScaleDimensions = new SizeF(96F, 96F);
            f.AutoScaleMode = AutoScaleMode.Dpi;
            f.Text = titulo;
            f.ClientSize = new Size(w, h);
            f.StartPosition = FormStartPosition.CenterScreen;
            f.FormBorderStyle = FormBorderStyle.FixedDialog;
            f.MaximizeBox = false; f.MinimizeBox = true;
            f.BackColor = Fundo; f.ForeColor = Texto;
            f.Font = new Font("Segoe UI", 9.75F);
            try { f.Icon = Icon.ExtractAssociatedIcon(Program.Exe); } catch { }
            return f;
        }
        public static Label Rotulo(Control pai, string txt, int x, int y, int w, int h)
        {
            Label l = new Label(); l.Text = txt; l.SetBounds(x, y, w, h); l.AutoEllipsis = true; pai.Controls.Add(l); return l;
        }
        public static TextBox Caixa(Control pai, int x, int y, int w)
        {
            TextBox t = new TextBox(); t.SetBounds(x, y, w, 26); t.BackColor = Campo; t.ForeColor = Texto;
            t.BorderStyle = BorderStyle.FixedSingle; pai.Controls.Add(t); return t;
        }
        public static ComboBox Combo(Control pai, int x, int y, int w, bool livre)
        {
            ComboBox c = new ComboBox(); c.SetBounds(x, y, w, 26);
            c.DropDownStyle = livre ? ComboBoxStyle.DropDown : ComboBoxStyle.DropDownList;
            c.BackColor = Campo; c.ForeColor = Texto; c.FlatStyle = FlatStyle.Flat; pai.Controls.Add(c); return c;
        }
        public static Button Botao_(Control pai, string txt, int x, int y, int w, int h, bool cinza)
        {
            Button b = new Button(); b.Text = txt; b.SetBounds(x, y, w, h); b.FlatStyle = FlatStyle.Flat;
            b.BackColor = cinza ? BotaoCinza : Botao; b.ForeColor = Color.White; b.FlatAppearance.BorderSize = 0;
            b.UseVisualStyleBackColor = false; pai.Controls.Add(b); return b;
        }
        public static DialogResult Msg(string texto, string titulo, MessageBoxButtons b, MessageBoxIcon i)
        {
            return MessageBox.Show(texto, titulo, b, i);
        }
    }

    // ------------------------------------------------------------------ configuracao / json
    static class Json
    {
        public static JavaScriptSerializer S()
        {
            JavaScriptSerializer s = new JavaScriptSerializer(); s.MaxJsonLength = int.MaxValue; s.RecursionLimit = 100; return s;
        }
        public static Dictionary<string, object> LerObj(string path)
        {
            try { return S().Deserialize<Dictionary<string, object>>(File.ReadAllText(path, Encoding.UTF8)); }
            catch { return new Dictionary<string, object>(); }
        }
        public static string Str(Dictionary<string, object> d, string k)
        {
            object v; if (d != null && d.TryGetValue(k, out v) && v != null) return Convert.ToString(v); return "";
        }
    }

    static class Cfg
    {
        static string Caminho { get { return Path.Combine(Program.Root, "config.json"); } }
        public static Dictionary<string, object> Ler() { return File.Exists(Caminho) ? Json.LerObj(Caminho) : new Dictionary<string, object>(); }
        public static string Get(string k) { return Json.Str(Ler(), k); }
        public static void Set(string k, string v)
        {
            Dictionary<string, object> d = Ler(); d[k] = v;
            File.WriteAllText(Caminho, Json.S().Serialize(d), new UTF8Encoding(true));
        }
        public static string PastaEquipe()
        {
            string p = Get("pastaEquipe"); return (p != "" && Directory.Exists(p)) ? p : null;
        }
    }

    // ------------------------------------------------------------------ lista de pecas (manifesto.json)
    class Item { public string D; public string U; public string[] C; public long S; }

    static class Manifesto
    {
        public static List<Item> Ler()
        {
            List<Item> r = new List<Item>();
            string p = Path.Combine(Program.Root, "manifesto.json");
            if (!File.Exists(p)) return r;
            object o = Json.S().DeserializeObject(File.ReadAllText(p, Encoding.UTF8));
            foreach (object x in (IEnumerable)o)
            {
                Dictionary<string, object> d = (Dictionary<string, object>)x;
                Item it = new Item();
                it.D = Json.Str(d, "d"); it.U = Json.Str(d, "u"); it.S = d.ContainsKey("s") && d["s"] != null ? Convert.ToInt64(d["s"]) : 0;
                List<string> c = new List<string>();
                object co; if (d.TryGetValue("c", out co) && co is IEnumerable && !(co is string)) foreach (object e in (IEnumerable)co) c.Add(Convert.ToString(e));
                it.C = c.ToArray();
                r.Add(it);
            }
            return r;
        }
        static string Chave(string s) { return Regex.Replace(s.ToLowerInvariant(), @"\.(step|stp)$", ""); }
        public static Item Achar(string chave)
        {
            string k = Chave(chave.Replace('\\', '/'));
            foreach (Item it in Ler()) if (Chave(it.D) == k) return it;
            return null;
        }
        public static string Destino(Item it) { return Path.Combine(Program.Root, it.D.Replace('/', '\\')); }
        public static bool Tudo_Pular(Item it) { return it.D.StartsWith("REV/ION") || it.D.Contains("Robotics Competition") || it.D.Contains(" (FRC)/"); }
    }

    // ------------------------------------------------------------------ download e extracao
    static class Rede
    {
        // user-agent completo: o site da WCP recusa (406) quem se apresenta so como "Mozilla/5.0"
        public const string Agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
        public static void Preparar()
        {
            try { ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; } catch { }
            ServicePointManager.DefaultConnectionLimit = 32;
        }
        // devolve false se foi cancelado. aoProgresso(lidos,total) devolve true para cancelar.
        public static bool Baixar(string url, string tmp, Func<long, long, bool> aoProgresso)
        {
            HttpWebRequest rq = (HttpWebRequest)WebRequest.Create(url);
            rq.UserAgent = Rede.Agente; rq.Timeout = 30000; rq.ReadWriteTimeout = 30000;
            using (WebResponse rs = rq.GetResponse())
            using (Stream ent = rs.GetResponseStream())
            using (FileStream sai = File.Create(tmp))
            {
                long total = rs.ContentLength, lido = 0; byte[] buf = new byte[65536]; int n;
                while ((n = ent.Read(buf, 0, buf.Length)) > 0)
                {
                    sai.Write(buf, 0, n); lido += n;
                    if (aoProgresso != null && aoProgresso(lido, total)) return false;
                }
            }
            return true;
        }
        public static string Texto(string nome, int timeoutMs)
        {
            HttpWebRequest rq = (HttpWebRequest)WebRequest.Create(Program.Base + nome + "?t=" + Guid.NewGuid().ToString("N"));
            rq.UserAgent = Rede.Agente; rq.Timeout = timeoutMs; rq.ReadWriteTimeout = timeoutMs;
            using (WebResponse rs = rq.GetResponse())
            using (StreamReader sr = new StreamReader(rs.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
        }
        public static void Arquivo(string nome, string destino)
        {
            string tmp = destino + ".novo";
            Baixar(Program.Base + nome + "?t=" + Guid.NewGuid().ToString("N"), tmp, null);
            if (new FileInfo(tmp).Length < 100) { File.Delete(tmp); throw new Exception("arquivo inválido: " + nome); }
            if (File.Exists(destino)) File.Delete(destino);
            File.Move(tmp, destino);
        }
    }

    static class Pecas
    {
        // tira a peca do arquivo baixado (zip, inclusive zip dentro de zip) e confere o cabecalho STEP
        public static void Instalar(Item it, string tmp)
        {
            string final = Manifesto.Destino(it);
            string dir = Path.GetDirectoryName(final);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            string parcial = final + ".part";
            try
            {
                if (it.C.Length == 0) File.Copy(tmp, parcial, true);
                else
                {
                    using (FileStream fs = File.OpenRead(tmp))
                    {
                        ZipArchive zip = new ZipArchive(fs, ZipArchiveMode.Read);
                        for (int i = 0; i < it.C.Length; i++)
                        {
                            string nome = it.C[i].Replace('\\', '/');
                            ZipArchiveEntry e = null;
                            foreach (ZipArchiveEntry z in zip.Entries) if (z.FullName.Replace('\\', '/') == nome) { e = z; break; }
                            if (e == null) throw new Exception("entrada não achada no zip: " + nome);
                            if (i < it.C.Length - 1)
                            {
                                MemoryStream ms = new MemoryStream();
                                using (Stream es = e.Open()) es.CopyTo(ms);
                                ms.Position = 0; zip = new ZipArchive(ms, ZipArchiveMode.Read);
                            }
                            else using (Stream es = e.Open()) using (FileStream o = File.Create(parcial)) es.CopyTo(o);
                        }
                    }
                }
                byte[] b = new byte[40]; int n;
                using (FileStream f2 = File.OpenRead(parcial)) n = f2.Read(b, 0, 40);
                if (!Encoding.ASCII.GetString(b, 0, n).Contains("ISO-10303")) throw new Exception("o arquivo baixado não é um STEP");
                if (File.Exists(final)) File.Delete(final);
                File.Move(parcial, final);
            }
            finally { if (File.Exists(parcial)) { try { File.Delete(parcial); } catch { } } }
        }
    }

    // ------------------------------------------------------------------ catalogo: listas lidas pelo catalogo.html
    static class Listas
    {
        public static int Baixadas()
        {
            string raiz = Program.Root.TrimEnd('\\', '/');
            List<string> l = new List<string>();
            try
            {
                foreach (string f in Directory.EnumerateFiles(raiz, "*.*", SearchOption.AllDirectories))
                {
                    string ext = Path.GetExtension(f).ToLowerInvariant();
                    if (ext != ".step" && ext != ".stp") continue;
                    string rel = f.Substring(raiz.Length + 1).Replace('\\', '/');
                    if (rel.StartsWith("_KITS", StringComparison.OrdinalIgnoreCase)) continue;
                    l.Add(Regex.Replace(rel, @"\.(step|stp)$", "", RegexOptions.IgnoreCase).ToLowerInvariant());
                }
            }
            catch { }
            File.WriteAllText(Path.Combine(raiz, "baixadas.js"), "window.BAIXADAS = " + Json.S().Serialize(l) + ";", new UTF8Encoding(false));
            return l.Count;
        }

        public static int Extras()
        {
            string saida = Path.Combine(Program.Root, "extras.js");
            string pasta = Cfg.PastaEquipe();
            List<Dictionary<string, object>> l = new List<Dictionary<string, object>>();
            if (pasta != null)
            {
                string baseDir = Path.Combine(pasta, "Pecas");
                if (Directory.Exists(baseDir))
                {
                    foreach (string j in Directory.GetFiles(baseDir, "*.json", SearchOption.AllDirectories))
                    {
                        try
                        {
                            Dictionary<string, object> m = Json.LerObj(j);
                            string step = j.Substring(0, j.Length - 5);
                            if (!File.Exists(step)) continue;
                            string tipo = Json.Str(m, "tipo"); if (tipo == "") tipo = "Outros";
                            string fab = Json.Str(m, "fab"); if (fab == "") fab = "Outro";
                            string grupo = Json.Str(m, "grupo").Trim();
                            string nome = Json.Str(m, "nome"); if (nome == "") nome = Path.GetFileNameWithoutExtension(step);
                            if (Json.Str(m, "codigo") != "") nome = Json.Str(m, "codigo") + " - " + nome;
                            string foto = "";
                            if (Json.Str(m, "foto") != "")
                            {
                                string fp = Path.Combine(baseDir, Json.Str(m, "foto"));
                                if (File.Exists(fp)) { try { foto = new Uri(fp).AbsoluteUri; } catch { } }
                            }
                            Dictionary<string, object> e = new Dictionary<string, object>();
                            e["n"] = nome; e["p"] = "Equipe/" + tipo;
                            e["s"] = Math.Round(new FileInfo(step).Length / 1048576.0, 1);
                            e["i"] = foto; e["t"] = nome + " " + fab + " " + grupo + " equipe " + Json.Str(m, "por");
                            e["u"] = Json.Str(m, "link"); e["f"] = 0; e["m"] = grupo != "" ? grupo : fab; e["gr"] = grupo;
                            e["v"] = fab; e["g"] = tipo; e["x"] = 1; e["b"] = Json.Str(m, "por"); e["a"] = step;
                            l.Add(e);
                        }
                        catch { }
                    }
                }
            }
            File.WriteAllText(saida, "window.EXTRAS = " + Json.S().Serialize(l) + ";", new UTF8Encoding(false));
            return l.Count;
        }

        public static List<string> Grupos(string pasta)
        {
            List<string> g = new List<string>();
            string b = Path.Combine(pasta, "Pecas");
            if (Directory.Exists(b))
                foreach (string j in Directory.GetFiles(b, "*.json", SearchOption.AllDirectories))
                {
                    string x = Json.Str(Json.LerObj(j), "grupo").Trim();
                    if (x != "" && !g.Contains(x)) g.Add(x);
                }
            g.Sort(); return g;
        }
    }

    // ------------------------------------------------------------------ integracao com o Windows (atalhos, endereco ftccad://)
    static class Sistema
    {
        public static void Atalhos(bool soExistentes)
        {
            string[] destinos = new string[] {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Catálogo FTC_CAD.lnk"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Catálogo FTC_CAD.lnk") };
            // atalhos antigos (versao com PowerShell) sao trocados pelo novo
            string[] antigos = new string[] {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Catalogo FTC_CAD.lnk"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Catalogo FTC_CAD.lnk") };
            bool teveAntigo = false;
            foreach (string a in antigos) if (File.Exists(a)) { teveAntigo = true; try { File.Delete(a); } catch { } }
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            if (t == null) return;
            object sh = Activator.CreateInstance(t);
            foreach (string lnk in destinos)
            {
                if (soExistentes && !teveAntigo && !File.Exists(lnk)) continue;
                object sc = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { lnk });
                Type st = sc.GetType();
                st.InvokeMember("TargetPath", BindingFlags.SetProperty, null, sc, new object[] { Program.Exe });
                st.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, sc, new object[] { Program.Root });
                st.InvokeMember("IconLocation", BindingFlags.SetProperty, null, sc, new object[] { Program.Exe + ",0" });
                st.InvokeMember("Description", BindingFlags.SetProperty, null, sc, new object[] { "Catálogo de peças FTC_CAD" });
                st.InvokeMember("Save", BindingFlags.InvokeMethod, null, sc, null);
            }
        }

        // so para o usuario atual (HKCU), nao precisa de administrador
        public static void Protocolo()
        {
            try
            {
                using (RegistryKey k = Registry.CurrentUser.CreateSubKey(@"Software\Classes\ftccad"))
                {
                    k.SetValue("", "URL:FTC CAD"); k.SetValue("URL Protocol", "");
                    using (RegistryKey ic = k.CreateSubKey("DefaultIcon")) ic.SetValue("", "\"" + Program.Exe + "\",0");
                    using (RegistryKey c = k.CreateSubKey(@"shell\open\command")) c.SetValue("", "\"" + Program.Exe + "\" \"%1\"");
                }
            }
            catch { }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto, Pack = 2)]
        struct SHFILEOPSTRUCT { public IntPtr hwnd; public uint wFunc; public string pFrom; public string pTo; public ushort fFlags; public int fAnyOperationsAborted; public IntPtr hNameMappings; public string lpszProgressTitle; }
        [DllImport("shell32.dll", CharSet = CharSet.Auto)] static extern int SHFileOperation(ref SHFILEOPSTRUCT op);

        public static void ParaLixeira(string p)
        {
            if (!File.Exists(p)) return;
            SHFILEOPSTRUCT op = new SHFILEOPSTRUCT();
            op.wFunc = 3; op.pFrom = p + "\0\0"; op.fFlags = 0x0040 | 0x0010 | 0x0004 | 0x0400; // lixeira, sem perguntar, sem janela, sem erro
            int r = SHFileOperation(ref op);
            if (r != 0 && File.Exists(p)) File.Delete(p);
        }

        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    }

    // ------------------------------------------------------------------ janela de progresso
    class JanelaProgresso : Form
    {
        public Label LNome, LStatus, LDetalhe; public ProgressBar Barra; public Button Btn;
        public volatile bool Cancelar;
        public JanelaProgresso(string titulo, string nome, int w)
        {
            AutoScaleDimensions = new SizeF(96F, 96F); AutoScaleMode = AutoScaleMode.Dpi;
            Text = titulo; ClientSize = new Size(w, 170); StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false;
            BackColor = Tema.Fundo; ForeColor = Tema.Texto; Font = new Font("Segoe UI", 9.75F);
            try { Icon = Icon.ExtractAssociatedIcon(Program.Exe); } catch { }
            LNome = Tema.Rotulo(this, nome, 20, 14, w - 40, 26); LNome.Font = new Font("Segoe UI Semibold", 11.5F); LNome.ForeColor = Tema.Titulo;
            LStatus = Tema.Rotulo(this, "Conectando...", 20, 48, w - 40, 22);
            Barra = new ProgressBar(); Barra.SetBounds(20, 76, w - 40, 22); Barra.Minimum = 0; Barra.Maximum = 1000; Controls.Add(Barra);
            LDetalhe = Tema.Rotulo(this, "", 20, 104, w - 40, 22); LDetalhe.ForeColor = Tema.Suave;
            Btn = Tema.Botao_(this, "Cancelar", w - 140, 128, 120, 32, false);
            Btn.Click += delegate { if (Btn.Text == "Fechar") Close(); else { Cancelar = true; Btn.Enabled = false; LStatus.Text = "Cancelando..."; } };
            FormClosing += delegate { Cancelar = true; };
        }
        public void Ui(Action a) { try { if (IsHandleCreated && !IsDisposed) BeginInvoke(a); } catch { } }
        public void Progresso(long lido, long total)
        {
            Ui(delegate
            {
                if (total > 0) { Barra.Value = (int)Math.Min(1000, 1000 * lido / total); LStatus.Text = string.Format("Baixando... {0:0.0} de {1:0.0} MB", lido / 1048576.0, total / 1048576.0); }
                else LStatus.Text = string.Format("Baixando... {0:0.0} MB", lido / 1048576.0);
            });
        }
    }

    // ------------------------------------------------------------------ baixar UMA peca (clique no catalogo)
    static class Baixar
    {
        public static void Rodar(string arquivo)
        {
            Item it = Manifesto.Achar(arquivo);
            if (it == null) { Tema.Msg("Não encontrei essa peça na lista do catálogo.", "Baixar peça - FTC_CAD", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            string destino = Manifesto.Destino(it);
            string nome = Path.GetFileNameWithoutExtension(destino);
            JanelaProgresso f = new JanelaProgresso("Baixar peça - FTC_CAD", nome, 520);
            bool ok = false; string erro = null;
            f.Shown += delegate
            {
                Thread th = new Thread(delegate()
                {
                    string tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".bin");
                    try
                    {
                        if (File.Exists(destino) && new FileInfo(destino).Length > 0) ok = true;
                        else if (Rede.Baixar(it.U, tmp, delegate(long l, long t) { f.Progresso(l, t); return f.Cancelar; }))
                        {
                            f.Ui(delegate { f.Barra.Style = ProgressBarStyle.Marquee; f.LStatus.Text = "Extraindo e conferindo o arquivo..."; });
                            Pecas.Instalar(it, tmp); ok = true;
                        }
                    }
                    catch (Exception ex) { erro = ex.Message; }
                    finally { try { if (File.Exists(tmp)) File.Delete(tmp); } catch { } }
                    f.Ui(delegate
                    {
                        if (!ok) { f.Close(); return; }
                        try { Clipboard.SetText(destino); } catch { }
                        try { Listas.Baixadas(); } catch { }
                        f.Barra.Style = ProgressBarStyle.Blocks; f.Barra.Value = 1000;
                        f.LStatus.Text = "Pronto! O caminho do arquivo foi copiado."; f.LDetalhe.Text = destino;
                        f.Cancelar = false; f.Btn.Enabled = true; f.Btn.Text = "Fechar";
                        System.Windows.Forms.Timer tm = new System.Windows.Forms.Timer(); tm.Interval = 1800;
                        tm.Tick += delegate { tm.Stop(); f.Close(); }; tm.Start();
                    });
                });
                th.IsBackground = true; th.Start();
            };
            f.ShowDialog();
            if (!ok && erro != null) Tema.Msg("Não consegui baixar:\r\n\r\n" + erro + "\r\n\r\nConfira a internet e tente de novo.", "Baixar peça - FTC_CAD", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ------------------------------------------------------------------ remover peca da equipe
    static class Remover
    {
        public static void Rodar(string arquivo)
        {
            string titulo = "Remover peça - FTC_CAD";
            string pasta = Cfg.PastaEquipe();
            if (pasta == null) { Tema.Msg("A pasta da equipe não está configurada.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            string baseDir = Path.GetFullPath(Path.Combine(pasta, "Pecas")).TrimEnd('\\', '/');
            string full = Path.GetFullPath(arquivo);
            if (!full.StartsWith(baseDir + "\\", StringComparison.OrdinalIgnoreCase)) { Tema.Msg("Esse arquivo não está na pasta da equipe.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            if (!full.EndsWith(".step", StringComparison.OrdinalIgnoreCase)) { Tema.Msg("Esse não é um arquivo .step.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            string json = full + ".json";
            if (!File.Exists(json)) { Tema.Msg("Esse arquivo não é uma peça adicionada pela equipe (não tem o .json).", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            Dictionary<string, object> m = Json.LerObj(json);
            string nome = Json.Str(m, "nome"); if (nome == "") nome = Path.GetFileNameWithoutExtension(full);
            if (Tema.Msg("Remover a peça '" + nome + "'?\r\n\r\nO arquivo vai para a Lixeira e some do catálogo de toda a equipe quando o Google Drive sincronizar.",
                titulo, MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;
            Sistema.ParaLixeira(full); Sistema.ParaLixeira(json);
            if (Json.Str(m, "foto") != "") Sistema.ParaLixeira(Path.Combine(baseDir, Json.Str(m, "foto")));
            Listas.Extras();
            Tema.Msg("Peça removida. O catálogo se atualiza sozinho ao voltar para a janela dele (ou aperte F5).", titulo, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    // ------------------------------------------------------------------ adicionar peca da equipe
    static class Adicionar
    {
        static readonly string[] Tipos = new string[] {
            "Colares e acopladores", "Correias e polias", "Correntes e coroas", "Cubos", "Dobradiças e molas", "Eixos e tubos", "Eletrônica", "Engrenagens",
            "Espaçadores e arruelas", "Esteiras", "Ferramentas", "Guias, slides e articulações", "Motores e caixas de redução", "Parafusos", "Placas e painéis", "Porcas",
            "Rodas e pneus", "Rolamentos", "Servos", "Suportes e bases", "Vigas e perfis", "Outros" };

        public static void Rodar()
        {
            string titulo = "Adicionar peça - FTC_CAD";
            string pasta = Cfg.PastaEquipe();
            if (pasta == null)
            {
                Tema.Msg("Escolha a pasta compartilhada da equipe.\r\n\r\nEla precisa ser uma pasta do seu computador que o Google Drive para computador sincroniza (por exemplo dentro de 'Meu Drive' ou 'Drives compartilhados'). Todos da equipe escolhem a mesma pasta do Drive.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Information);
                using (FolderBrowserDialog fb = new FolderBrowserDialog())
                {
                    fb.Description = "Pasta compartilhada da equipe (sincronizada pelo Google Drive)";
                    if (fb.ShowDialog() != DialogResult.OK) return;
                    pasta = fb.SelectedPath; Cfg.Set("pastaEquipe", pasta);
                }
            }
            string pastaEq = pasta;
            Form f = Tema.Janela(titulo, 560, 500);
            string[] arquivos = new string[0];
            Tema.Rotulo(f, "Arquivo(s) .step (pode escolher vários)", 20, 14, 520, 20);
            TextBox txtArq = Tema.Caixa(f, 20, 36, 400); txtArq.ReadOnly = true;
            Button btnArq = Tema.Botao_(f, "Procurar...", 430, 35, 110, 28, false);
            Tema.Rotulo(f, "Nome da peça (com vários arquivos, usa o nome de cada arquivo)", 20, 74, 520, 20);
            TextBox txtNome = Tema.Caixa(f, 20, 96, 520);
            Tema.Rotulo(f, "Código (opcional, ex.: 2101-0006-0001)", 20, 134, 520, 20);
            TextBox txtCod = Tema.Caixa(f, 20, 156, 520);
            Tema.Rotulo(f, "Fabricante", 20, 194, 250, 20);
            ComboBox cmbFab = Tema.Combo(f, 20, 216, 250, true); cmbFab.Items.AddRange(new object[] { "goBILDA", "REV", "AndyMark", "Outro" }); cmbFab.Text = "Outro";
            Tema.Rotulo(f, "Tipo de peça", 290, 194, 250, 20);
            ComboBox cmbTipo = Tema.Combo(f, 290, 216, 250, false); cmbTipo.Items.AddRange(Tipos); cmbTipo.SelectedItem = "Outros";
            Tema.Rotulo(f, "Grupo (opcional): aparece junto dos fabricantes e como etiqueta", 20, 254, 520, 20);
            ComboBox cmbGrupo = Tema.Combo(f, 20, 276, 520, true);
            try { foreach (string g in Listas.Grupos(pastaEq)) cmbGrupo.Items.Add(g); } catch { }
            Tema.Rotulo(f, "Link da página do produto (opcional)", 20, 314, 520, 20);
            TextBox txtLink = Tema.Caixa(f, 20, 336, 520);
            Tema.Rotulo(f, "Foto da peça (opcional, .jpg ou .png)", 20, 374, 520, 20);
            TextBox txtFoto = Tema.Caixa(f, 20, 396, 400); txtFoto.ReadOnly = true;
            Button btnFoto = Tema.Botao_(f, "Procurar...", 430, 395, 110, 28, false);
            Label lp = Tema.Rotulo(f, "Pasta da equipe: " + pastaEq, 20, 434, 520, 20); lp.ForeColor = Tema.Suave;
            Button ok = Tema.Botao_(f, "Adicionar", 300, 460, 120, 30, false);
            Button cancel = Tema.Botao_(f, "Cancelar", 430, 460, 110, 30, true);
            cancel.Click += delegate { f.Close(); };

            btnArq.Click += delegate
            {
                using (OpenFileDialog d = new OpenFileDialog())
                {
                    d.Filter = "Modelos STEP (*.step;*.stp)|*.step;*.stp"; d.Multiselect = true;
                    if (d.ShowDialog() != DialogResult.OK) return;
                    arquivos = d.FileNames;
                    if (arquivos.Length == 1)
                    {
                        txtArq.Text = arquivos[0]; if (txtNome.Text == "") txtNome.Text = Path.GetFileNameWithoutExtension(arquivos[0]);
                        txtNome.Enabled = true; txtCod.Enabled = true;
                    }
                    else { txtArq.Text = arquivos.Length + " arquivos selecionados"; txtNome.Text = ""; txtNome.Enabled = false; txtCod.Text = ""; txtCod.Enabled = false; }
                }
            };
            btnFoto.Click += delegate
            {
                using (OpenFileDialog d = new OpenFileDialog()) { d.Filter = "Imagens (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png"; if (d.ShowDialog() == DialogResult.OK) txtFoto.Text = d.FileName; }
            };
            ok.Click += delegate
            {
                if (arquivos.Length == 0) { Tema.Msg("Escolha pelo menos um arquivo .step.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
                if (arquivos.Length == 1 && txtNome.Text.Trim() == "") { Tema.Msg("Digite o nome da peça.", titulo, MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
                string tipo = Convert.ToString(cmbTipo.SelectedItem);
                string dirTipo = Path.Combine(Path.Combine(pastaEq, "Pecas"), tipo);
                Directory.CreateDirectory(dirTipo);
                int feitas = 0; List<string> puladas = new List<string>();
                foreach (string arq in arquivos)
                {
                    string nomeArq = Path.GetFileName(arq);
                    if (nomeArq.EndsWith(".stp", StringComparison.OrdinalIgnoreCase)) nomeArq = Path.GetFileNameWithoutExtension(nomeArq) + ".step";
                    string dest = Path.Combine(dirTipo, nomeArq);
                    if (File.Exists(dest) && Tema.Msg("Já existe uma peça com o arquivo '" + nomeArq + "' nessa pasta. Substituir?", titulo, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                    { puladas.Add(nomeArq); continue; }
                    File.Copy(arq, dest, true);
                    string foto = "";
                    if (txtFoto.Text != "" && File.Exists(txtFoto.Text) && arquivos.Length == 1)
                    {
                        string dirFotos = Path.Combine(Path.Combine(pastaEq, "Pecas"), "_fotos"); Directory.CreateDirectory(dirFotos);
                        string fn = Path.GetFileNameWithoutExtension(nomeArq) + Path.GetExtension(txtFoto.Text);
                        File.Copy(txtFoto.Text, Path.Combine(dirFotos, fn), true); foto = "_fotos\\" + fn;
                    }
                    Dictionary<string, object> meta = new Dictionary<string, object>();
                    meta["nome"] = arquivos.Length == 1 ? txtNome.Text.Trim() : Path.GetFileNameWithoutExtension(nomeArq);
                    meta["codigo"] = arquivos.Length == 1 ? txtCod.Text.Trim() : "";
                    meta["fab"] = cmbFab.Text.Trim(); meta["grupo"] = cmbGrupo.Text.Trim(); meta["tipo"] = tipo; meta["link"] = txtLink.Text.Trim(); meta["foto"] = foto;
                    meta["por"] = Environment.UserName; meta["data"] = DateTime.Now.ToString("yyyy-MM-dd");
                    File.WriteAllText(dest + ".json", Json.S().Serialize(meta), new UTF8Encoding(true));
                    feitas++;
                }
                Listas.Extras();
                string msg = feitas + " peça(s) adicionada(s) em:\r\n" + dirTipo + "\r\n\r\nO catálogo se atualiza sozinho ao voltar para ele (ou aperte F5). O Google Drive envia para a equipe em alguns instantes.";
                if (puladas.Count > 0) msg += "\r\n\r\nNão substituídas: " + string.Join(", ", puladas.ToArray());
                Tema.Msg(msg, titulo, MessageBoxButtons.OK, MessageBoxIcon.Information);
                f.Close();
            };
            f.ShowDialog();
        }
    }

    // ------------------------------------------------------------------ instalacao (primeira abertura)
    static class Instalacao
    {
        // devolve true se instalou (ou ja estava instalado), false se cancelou
        public static bool Rodar()
        {
            List<Item> todos = Manifesto.Ler();
            List<Item> faltam = new List<Item>(); long bytes = 0;
            foreach (Item it in todos)
            {
                if (Manifesto.Tudo_Pular(it) || it.S > 20L * 1048576) continue;
                string d = Manifesto.Destino(it);
                if (File.Exists(d) && new FileInfo(d).Length > 0) continue;
                faltam.Add(it); bytes += it.S;
            }
            Form f = Tema.Janela("Instalador FTC_CAD", 560, 300);
            Label t = Tema.Rotulo(f, "Biblioteca de modelos STEP - FTC", 20, 14, 520, 30); t.Font = new Font("Segoe UI Semibold", 13F); t.ForeColor = Tema.Titulo;
            Label st = Tema.Rotulo(f, "Como você quer instalar?", 20, 52, 520, 24);
            RadioButton r1 = new RadioButton(); r1.Text = "Só o catálogo (recomendado)\r\nCada peça é baixada na hora em que você clica nela."; r1.Checked = true; r1.SetBounds(24, 84, 510, 48); f.Controls.Add(r1);
            RadioButton r2 = new RadioButton(); r2.Text = string.Format("Baixar todas as peças agora\r\n{0} arquivos, cerca de {1:0.0} GB depois de extraídos. Demora.", faltam.Count, bytes / 1073741824.0); r2.SetBounds(24, 138, 510, 48); f.Controls.Add(r2);
            if (faltam.Count == 0) r2.Enabled = false;
            ProgressBar barra = new ProgressBar(); barra.SetBounds(20, 200, 520, 22); barra.Minimum = 0; barra.Maximum = 1000; barra.Visible = false; f.Controls.Add(barra);
            Label det = Tema.Rotulo(f, "", 20, 226, 520, 22); det.ForeColor = Tema.Suave;
            Button go = Tema.Botao_(f, "Instalar", 300, 252, 120, 34, false);
            Button cancel = Tema.Botao_(f, "Cancelar", 430, 252, 110, 34, true);

            bool concluido = false, rodando = false; volatile_ cancelar = new volatile_();
            long feitoBytes = 0; int criados = 0; List<string> falhas = new List<string>();
            cancel.Click += delegate { if (rodando) { cancelar.V = true; cancel.Enabled = false; st.Text = "Cancelando..."; } else f.Close(); };
            f.FormClosing += delegate { if (rodando) cancelar.V = true; };

            go.Click += delegate
            {
                bool tudo = r2.Checked;
                r1.Visible = false; r2.Visible = false; go.Enabled = false; rodando = true;
                if (!tudo)
                {
                    st.Text = "Instalando..."; Finalizar(tudo); concluido = true; rodando = false; f.Close(); return;
                }
                st.Text = "Baixando as peças... pode fechar e abrir de novo depois: o que já foi baixado é mantido."; barra.Visible = true;
                System.Windows.Forms.Timer tm = new System.Windows.Forms.Timer(); tm.Interval = 300;
                tm.Tick += delegate
                {
                    long fb = Interlocked.Read(ref feitoBytes);
                    barra.Value = bytes > 0 ? (int)Math.Min(1000, 1000 * fb / bytes) : 1000;
                    det.Text = string.Format("{0:0} de {1:0} MB  |  {2} arquivos prontos  |  {3} falhas", fb / 1048576.0, bytes / 1048576.0, criados, falhas.Count);
                };
                tm.Start();
                // agrupa por endereco: um zip pode ter varias pecas
                Dictionary<string, List<Item>> grupos = new Dictionary<string, List<Item>>();
                foreach (Item it in faltam) { List<Item> l; if (!grupos.TryGetValue(it.U, out l)) { l = new List<Item>(); grupos[it.U] = l; } l.Add(it); }
                Thread th = new Thread(delegate()
                {
                    ParallelOptions po = new ParallelOptions(); po.MaxDegreeOfParallelism = 6;
                    Parallel.ForEach(grupos, po, delegate(KeyValuePair<string, List<Item>> g)
                    {
                        if (cancelar.V) return;
                        string tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".bin");
                        long peso = 0; foreach (Item it in g.Value) peso += it.S;
                        try
                        {
                            bool bom = false;
                            for (int tent = 1; tent <= 4 && !bom && !cancelar.V; tent++)
                            {
                                try { Rede.Baixar(g.Key, tmp, delegate(long l, long tt) { return cancelar.V; }); bom = true; }
                                catch { Thread.Sleep(2000 * tent); }
                            }
                            if (!bom) { if (!cancelar.V) lock (falhas) falhas.Add("download falhou: " + g.Key); return; }
                            foreach (Item it in g.Value)
                            {
                                try { Pecas.Instalar(it, tmp); Interlocked.Increment(ref criados); }
                                catch (Exception ex) { lock (falhas) falhas.Add(it.D + " -> " + ex.Message); }
                            }
                        }
                        finally { try { if (File.Exists(tmp)) File.Delete(tmp); } catch { } Interlocked.Add(ref feitoBytes, peso); }
                    });
                    f.BeginInvoke((Action)delegate
                    {
                        tm.Stop(); rodando = false;
                        if (!cancelar.V)
                        {
                            Finalizar(true); concluido = true;
                            if (falhas.Count > 0) { try { File.WriteAllLines(Path.Combine(Program.Root, "falhas.txt"), falhas.ToArray(), new UTF8Encoding(true)); } catch { } }
                        }
                        f.Close();
                    });
                });
                th.IsBackground = true; th.Start();
            };
            f.ShowDialog();
            return concluido;
        }

        class volatile_ { public volatile bool V; }

        static void Finalizar(bool tudo)
        {
            Cfg.Set("modo", tudo ? "tudo" : "demanda");
            Sistema.Protocolo();
            Listas.Baixadas(); Listas.Extras();
            try { Sistema.Atalhos(false); } catch { }
        }
    }

    // ------------------------------------------------------------------ atualizacao e abertura do catalogo
    static class Abrir
    {
        public static void Rodar()
        {
            string verArq = Path.Combine(Program.Root, "versao.txt");
            string remoto = "";
            try { remoto = Rede.Texto("versao.txt", 4000).Trim(); } catch { }
            string local = File.Exists(verArq) ? File.ReadAllText(verArq).Trim() : "";
            if (remoto != "" && remoto != local)
            {
                Form splash = Splash("Atualizando o catálogo...");
                Task t = Task.Factory.StartNew(delegate()
                {
                    try
                    {
                        Rede.Arquivo("catalogo.html", Path.Combine(Program.Root, "catalogo.html"));
                        Rede.Arquivo("manifesto.json", Path.Combine(Program.Root, "manifesto.json"));
                        Rede.Arquivo("FTC_CAD.exe", Program.Exe + ".novo");      // troca na proxima abertura
                        File.WriteAllText(verArq, remoto);
                        File.AppendAllText(Path.Combine(Program.Root, "atualizacao.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm") + "  atualizado para " + remoto + "\r\n");
                    }
                    catch (Exception ex)
                    {
                        try { File.AppendAllText(Path.Combine(Program.Root, "atualizacao.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm") + "  sem atualização (" + ex.Message + ")\r\n"); } catch { }
                    }
                });
                while (!t.IsCompleted) { Application.DoEvents(); Thread.Sleep(30); }
                splash.Close();
                // modo "tudo": baixa em segundo plano as pecas novas que apareceram
                if (Cfg.Get("modo") == "tudo") { try { BaixarNovas(); } catch { } }
            }
            try { Sistema.Protocolo(); } catch { }
            try { Listas.Extras(); } catch { }
            try { Listas.Baixadas(); } catch { }
            try { Sistema.Atalhos(true); } catch { }
            AbrirCatalogo();
        }

        static void BaixarNovas()
        {
            List<Item> novas = new List<Item>();
            foreach (Item it in Manifesto.Ler())
                if (!Manifesto.Tudo_Pular(it) && it.S <= 20L * 1048576 && !File.Exists(Manifesto.Destino(it))) novas.Add(it);
            if (novas.Count == 0) return;
            Dictionary<string, List<Item>> grupos = new Dictionary<string, List<Item>>();
            foreach (Item it in novas) { List<Item> l; if (!grupos.TryGetValue(it.U, out l)) { l = new List<Item>(); grupos[it.U] = l; } l.Add(it); }
            Form splash = Splash("Baixando " + novas.Count + " peças novas...");
            Task t = Task.Factory.StartNew(delegate()
            {
                ParallelOptions po = new ParallelOptions(); po.MaxDegreeOfParallelism = 6;
                Parallel.ForEach(grupos, po, delegate(KeyValuePair<string, List<Item>> g)
                {
                    string tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".bin");
                    try { Rede.Baixar(g.Key, tmp, null); foreach (Item it in g.Value) { try { Pecas.Instalar(it, tmp); } catch { } } }
                    catch { }
                    finally { try { if (File.Exists(tmp)) File.Delete(tmp); } catch { } }
                });
            });
            while (!t.IsCompleted) { Application.DoEvents(); Thread.Sleep(30); }
            splash.Close();
        }

        static Form Splash(string texto)
        {
            Form f = new Form();
            f.AutoScaleDimensions = new SizeF(96F, 96F); f.AutoScaleMode = AutoScaleMode.Dpi;
            f.FormBorderStyle = FormBorderStyle.None; f.StartPosition = FormStartPosition.CenterScreen; f.ClientSize = new Size(360, 96);
            f.BackColor = Tema.Campo; f.ForeColor = Tema.Texto; f.TopMost = true; f.ShowInTaskbar = false; f.Font = new Font("Segoe UI", 9.75F);
            Label l = Tema.Rotulo(f, "Catálogo FTC_CAD", 20, 14, 320, 26); l.Font = new Font("Segoe UI Semibold", 12F); l.ForeColor = Tema.Titulo;
            Tema.Rotulo(f, texto, 20, 44, 320, 22);
            ProgressBar b = new ProgressBar(); b.Style = ProgressBarStyle.Marquee; b.MarqueeAnimationSpeed = 30; b.SetBounds(20, 72, 320, 8); f.Controls.Add(b);
            f.Show(); Application.DoEvents(); return f;
        }

        static void AbrirCatalogo()
        {
            string cat = Path.Combine(Program.Root, "catalogo.html");
            if (!File.Exists(cat)) { Tema.Msg("Não achei o catalogo.html nesta pasta.", "FTC_CAD", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            string pf86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)"), pf = Environment.GetEnvironmentVariable("ProgramFiles"), la = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            List<string> c = new List<string>();
            if (pf86 != null) c.Add(Path.Combine(pf86, @"Microsoft\Edge\Application\msedge.exe"));
            if (pf != null) { c.Add(Path.Combine(pf, @"Microsoft\Edge\Application\msedge.exe")); c.Add(Path.Combine(pf, @"Google\Chrome\Application\chrome.exe")); }
            if (pf86 != null) c.Add(Path.Combine(pf86, @"Google\Chrome\Application\chrome.exe"));
            if (la != null) c.Add(Path.Combine(la, @"Google\Chrome\Application\chrome.exe"));
            foreach (string b in c)
                if (File.Exists(b)) { Process.Start(b, "--app=\"" + new Uri(cat).AbsoluteUri + "\""); return; }
            Process.Start(cat);
        }
    }

    // ------------------------------------------------------------------ programa
    static class Program
    {
        public const string Base = "https://raw.githubusercontent.com/aragaojonnas-png/ftc-cad-catalogo/main/";
        public static string Root, Exe;

        [STAThread]
        static int Main(string[] args)
        {
            try { Sistema.SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Exe = Application.ExecutablePath; Root = Path.GetDirectoryName(Exe);
            Rede.Preparar();
            TrocarVersao();
            try
            {
                string a = args.Length > 0 ? args[0] : "";
                if (a.StartsWith("ftccad://", StringComparison.OrdinalIgnoreCase))
                {
                    string acao = Regex.Match(a, @"^ftccad://([a-z]+)", RegexOptions.IgnoreCase).Groups[1].Value.ToLowerInvariant();
                    string arq = null; Match m = Regex.Match(a, @"[?&]arquivo=([^&]+)");
                    if (m.Success) arq = Uri.UnescapeDataString(m.Groups[1].Value);
                    if (acao == "baixar") { if (arq != null) Baixar.Rodar(arq); }
                    else if (acao == "remover") { if (arq != null) Remover.Rodar(arq); }
                    else Adicionar.Rodar();
                    return 0;
                }
                if (a == "--instalar" || Cfg.Get("modo") == "") { if (!Instalacao.Rodar()) return 0; }
                Abrir.Rodar();
            }
            catch (Exception ex)
            {
                Tema.Msg("Erro: " + ex.Message, "FTC_CAD", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
            return 0;
        }

        // aplica a versao nova do proprio programa baixada na abertura anterior (o Windows deixa renomear um .exe em uso)
        static void TrocarVersao()
        {
            try
            {
                string novo = Exe + ".novo", velho = Exe + ".velho";
                if (File.Exists(velho)) { try { File.Delete(velho); } catch { } }
                if (File.Exists(novo) && new FileInfo(novo).Length > 10000)
                {
                    File.Move(Exe, velho); File.Move(novo, Exe);
                    string[] ca = Environment.GetCommandLineArgs();
                    Process.Start(Exe, ca.Length > 1 ? "\"" + ca[1] + "\"" : "");
                    Environment.Exit(0);
                }
            }
            catch { }
        }
    }
}
