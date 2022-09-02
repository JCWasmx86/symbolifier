/* main.vala
 *
 * Copyright 2022 JCWasmx86
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Usage {
	public string file;
	public string url;
	public int line;
}

public class Reference {
	public uint16 url;
	public uint16 file;
	public uint16 line;
}

uint hash (string s) {
	var h = 0;
	foreach (var c in s.data) {
		h = ((h << 5) -h) + c;
		h = h & h;
	}
	return h;
}

public class Data {
	private Usage[] usages;

	public Data () {
		this.usages = new Usage[0];
	}
	public void add (Usage u) {
		this.usages += u;
	}
	public void emit (OutputStream os) throws Error {
		var str_pool = new string[0];
		var arr = new Reference[0];
		foreach (var usage in usages) {
			var fileidx = -1;
			for (var i = 0; i < str_pool.length; i++) {
				if (str_pool[i] == usage.file) {
					fileidx = i;
					break;
				}
			}
			if (fileidx == -1) {
				str_pool += usage.file;
				fileidx = str_pool.length - 1;
			}
			var urlidx = -1;
			for (var i = 0; i < str_pool.length; i++) {
				if (str_pool[i] == usage.url) {
					urlidx = i;
					break;
				}
			}
			if (urlidx == -1) {
				str_pool += usage.url;
				urlidx = str_pool.length - 1;
			}
			arr += new Reference () {
				file = (uint16)fileidx,
				url = (uint16)urlidx,
				line = (uint16)usage.line
			};
		}
		var dos = new DataOutputStream (os);
		dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;
		dos.put_byte ('V');
		dos.put_byte ('A');
		dos.put_uint16 ((uint16)str_pool.length);
		foreach (var s in str_pool) {
			dos.put_string (s);
			dos.put_byte (0);
		}
		dos.put_byte (0xAA);
		foreach (var r in arr) {
			dos.put_byte ((uint8)(r.file & 0xFF));
			dos.put_byte ((uint8)((r.file >> 8) & 0xFF));
			dos.put_byte ((uint8)(r.url & 0xFF));
			dos.put_byte ((uint8)((r.url >> 8) & 0xFF));
			dos.put_byte ((uint8)(r.line & 0xFF));
			dos.put_byte ((uint8)((r.line >> 8) & 0xFF));
		}
	}
}

int main (string[] args) {
	var output = args[1];
	var table = new HashTable<string, Data> (str_hash, str_equal);
	for (var i = 2; i < args.length; i++) {
		string contents = "";
		size_t len = 0;
		try {
			FileUtils.get_contents (args[i], out contents, out len);
		} catch (Error e) {
			critical ("%s", e.message);
			return -1;
		}
		var lines = contents.split ("\n");
		foreach (var line in lines) {
			if (line == "")
				continue;
			var splitted = line.split(",");
			var symname = splitted[1];
			if (!(symname in table)) {
				table[symname] = new Data ();
			}
			table[symname].add (new Usage () {
				file = splitted[2].replace("../", ""),
				line = int.parse (splitted[3]),
				url = splitted[7]
			});
		}
	}
	var file = File.new_for_commandline_arg (output);
	try {
		file.make_directory_with_parents ();
	} catch (Error e) {
		critical ("(Ignore me) %s", e.message);
	}
	var sb = new StringBuilder ();
	foreach (var symbol in table.get_keys ()) {
		var h = hash (symbol);
		var filename = "%02x%02x%02x%02x.in".printf ((h >> 24) & 0xFF, (h >> 16) & 0xFF, (h >> 8) & 0xFF, (h >> 0) & 0xFF);
		critical (">> %s = %s", symbol, filename);
		var outputfile = file.get_child (filename);
		try {
			if (outputfile.query_exists ()) {
				outputfile.delete();
			}
			var os = outputfile.create (GLib.FileCreateFlags.NONE);
			table[symbol].emit (os);
			sb.append ("\t\t<button type=\"button\" id=\"%s\" onclick=\"navigate_to('%x')\">%s</button><br/>\n".printf (symbol.down ().replace(".", "_"), h, symbol));
		} catch (Error e) {
			critical ("%s", e.message);
		}
	}
	try {
		FileUtils.set_contents ("output__symbolifier.html", sb.str);
	} catch (Error e) {
		critical ("%s", e.message);
	}
	return 0;
}
