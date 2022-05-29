/* application.vala
 *
 * Copyright 2022 eexpress
 *
 */
// 需要在“构建配置”里面激活一项。有两个项目，不确定差别是什么。激活后，才能构建。
// ⭕ pi valac libadwaita-devel
using Gtk;
using Posix;
// meson.build基本可以自动创建和更新。
// Posix太特殊。需要手动添加到src/meson.build的dependency字段。
// meson.get_compiler('vala').find_library('posix'),
//   # error: The namespace name `Posix' could not be found
//   #  20 | using Posix;

namespace ClipQrcodeShare {
public
class Application : Adw.Application {

private
	Entry input;
private
	Image img;
private
	Label txt;
	// private ApplicationWindow win;

	const string pngfile = "/tmp/qrcode.png";
	const string linkdir = "/tmp/qrcode.lnk/";
	const string port	 = "12800";

public
	Application() {
		Object(application_id
			   : "org.eexpss.Clip_Qrcode_Share",
			   flags
			   : ApplicationFlags.FLAGS_NONE);
	}

	// 标题栏右侧的菜单。
	construct {
		ActionEntry[] action_entries = {
			{ "about", this.on_about_action },
			{ "preferences", this.on_preferences_action },
			{ "quit", this.quit }
		};
		this.add_action_entries(action_entries, this);
		this.set_accels_for_action("app.quit", { "<primary>q" });
	}
	// 窗口激活
public
	override void activate() {
		base.activate();
		var win = this.active_window;
		if (win == null) {
			win = new ClipQrcodeShare.Window(this);
		}
		// 检查调用的外部程序，缺少就退出。
		if (!check_app("qrencode")) return;
		if (!check_app("droopy")) return;

		string last_clip = "";
		string last_prim = "";
		mkdir(linkdir, 0750);
		chdir(linkdir);
		string ipadd   = get_lan_ip();
		string logopng = get_logo_png();

		// Posix.system("python3 -m http.server " + port + "&");  // 退出时正常杀死
		Posix.system(@"droopy -d $(linkdir) $(logopng) -m \"上传文件到<br>$(linkdir)\" --dl $(port) &");  // 退出时没杀死

		var pg = new Adw.PreferencesGroup();
		pg.set_margin_top(15);
		pg.set_margin_bottom(15);
		pg.set_margin_start(15);
		pg.set_margin_end(15);
		var clip = Gdk.Display.get_default().get_clipboard();
		var prim = Gdk.Display.get_default().get_primary_clipboard();

		input					  = new Entry();
		input.primary_icon_name	  = "edit-clear-all-symbolic";
		input.secondary_icon_name = "folder-saved-search-symbolic";
		input.icon_release.connect((pos) => {
			if (pos == EntryIconPosition.PRIMARY) {
				input.text = "";
			}
			if (pos == EntryIconPosition.SECONDARY) {
				string s = input.text;
				show(s);
			}
		});
		input.text = "version 0.2";
		pg.add(input);

		img = new Image();
		img.set_from_icon_name("edit-find-symbolic");
		img.pixel_size = 280;
		var gesture = new Gtk.GestureClick();
		gesture.released.connect((n_press, x, y) => {
			if (clip.formats.contain_gtype(typeof(string))) {
				clip.read_text_async.begin(
					null, (obj, res) => {
						try {
							string text = clip.read_text_async.end(res);
							if (text == null || text == "" || text == last_clip) return;
							last_clip = text;

							bool has_file	   = false;
							string[] filearray = text.split("\n");
							foreach (unowned string i in filearray) {
								File file = File.new_for_path(i);
								if (!file.query_exists()) continue;
								File link = File.new_for_path(linkdir + File.new_for_path(i).get_basename());
								if (link.query_exists()) continue;
								has_file = true;
								try {
									link.make_symbolic_link(i);
								} catch (Error e) { warning(e.message); }
							}
							if (!has_file) return;
							if (ipadd != null) {
								show(@"http://$(ipadd):$(port)/");	// ricotz
							} else {
								img.set_from_icon_name("webpage-symbolic");
							}
						} catch (Error e) { warning(e.message); }
						return;
					});
			}
			if (prim.formats.contain_gtype(typeof(string))) {  // Nahuel
				prim.read_text_async.begin(
					null, (obj, res) => {
						try {
							string text = prim.read_text_async.end(res);
							if (text == null || text == "" || text == last_prim) return;
							last_prim = text;
							show(text);
						} catch (Error e) { warning(e.message); }
						return;
					});
			}
		});
		img.add_controller(gesture);
		pg.add(img);

		txt		  = new Label("");
		txt.label = "null";
		pg.add(txt);

		win.set_title("Clip QRcode Share");
		win.set_child(pg);
		win.resizable	  = true;
		win.width_request = 300;
		//~ 		win.default_width = 300;
		// Gtk4 常规没有 above 了。只 GJS 提供 Meta.win 有这功能。
		//~ 		win.move(0,0);
		//~ 		win.set_position (WindowPosition.NONE);
		//~ 		win.make_above();

		win.present();
	}

protected
	override void shutdown() {	// 从 GLib.Application 继承的，应该是对应 activate
		try {
			GLib.Dir dir  = GLib.Dir.open(linkdir, 0);
			string ? name = null;
			while ((name = dir.read_name()) != null) {
				File file = File.new_for_path(name);
				file.delete();
			}
			rmdir(linkdir);
			File file = File.new_for_path(pngfile);
			file.delete();
		} catch (Error e) { }
		Posix.system("pkill droopy");
	}

private
	void show(string s) {
		if (s == null) {
			txt.label = "null";
			return;
		}
		print("show:" + s + "\n");
		txt.label = s;
		File file = File.new_for_path(pngfile);
		try {
			file.delete();
		} catch (Error e) { }

		// 直接修改s会导致溢出。需使用新变量 str。
		string str = s.replace("\\", "\\\\").replace("\$", "\\\$").replace("\"", "\\\"").replace("`", "\\`");
		//~ lwildberg: 反引号 ` 对于 vala 不需要转义。
		//~ 但是为了避免被 shell 当成执行语句，在 shell 需要转义。所以只添加一个反斜杠 \\ 。
		//~ error: invalid escape sequence ---> replace("\`", "\\\`")
		input.text = str;
		Posix.system(@"qrencode \"$(str)\" -o $(pngfile)");	 // depend qrencode + libqrencode4 + libpng16-16
		//~ 		var qrcode = new QRcode.encodeString(str, 0, EcLevel.H, Mode.B8, 1);	//depend libqrencode4
		//~ 		if (qrcode != null) {
		//~ 			for (int iy = 0; iy < qrcode.width; iy++) {
		//~ 				for (int ix = 0; ix < qrcode.width; ix++) {
		//~ 					if ((qrcode.data[iy * qrcode.width + ix] & 1) != 0) {
		//~ 						print("██");	//\u2588\u2588 full block
		//~ 					}else{
		//~ 						print("  ");
		//~ 					}
		//~ 				}
		//~ 				print("\n");
		//~ 			}
		//~ 		}
		// 单引号包裹字符串时，转义也失效，所以不能再包含单引号。由此只能使用双引号包裹字符串。
		img.set_from_file(pngfile);
	}

private
	string get_logo_png() {
		try {
			GLib.Dir dir  = GLib.Dir.open("/usr/share/plymouth/", 0);
			string ? name = null;
			while ((name = dir.read_name()) != null) {
				if (name.index_of("logo.png") >= 0) { return @"-p /usr/share/plymouth/$(name)"; };
			}
		} catch (Error e) { }
		return "";
	}

private
	string get_lan_ip() {
		Socket udp4;
		string ipv4 = null;
		try {
			udp4 = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
			GLib.assert(udp4 != null);
			udp4.connect(new InetSocketAddress.from_string("192.168.0.1", int.parse(port)));
			ipv4 = ((InetSocketAddress)udp4.local_address).address.to_string();
			//~ lwildberg: InetSocketAddress is derived from SocketAddress and adds the address property.
			udp4.close();
		} catch (Error e) {
			//~ 如果错写成 `catch (e)`, ninja 会吊死在后台。
			udp4 = null;
			ipv4 = null;
		}
		return ipv4;
	}

	static bool check_app(string app) {
		// 设置为 static，才能在未实例化前，内部调用
		string r = Environment.find_program_in_path(app);
		if (r == null) {
			//~ 			Main.notify(_(`Need install ${cmd} command.`));
			print(@"Need install $(app) command.");
			return false;
		}
		return true;
	}

private
	void on_about_action() {
		string[] authors = { "eexpress" };
		Gtk.show_about_dialog(this.active_window,
			"program-name", "clip-qrcode-share",
			"authors", authors,
			"version", "0.1.0");
	}

private
	void on_preferences_action() {
		message("app.preferences action activated");
	}
}
}
