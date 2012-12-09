import std.exception;
import std.string;

import win32.windows;

import ae.net.http.common;
import ae.net.http.responseex;
import ae.net.http.server;
import ae.net.asockets;

import ae.utils.text;
import ae.utils.textout;

import ae.sys.log;

struct Action { char link; string name, description; string function(string[] args) f; }
const Action[] actions =
[
	Action('s', "show"   , "show"         , function(string[] args) { ShowWindow  (parseHwnd(args[0]), SW_SHOW); return string.init; } ),
	Action('h', "hide"   , "hide"         , function(string[] args) { ShowWindow  (parseHwnd(args[0]), SW_HIDE); return string.init; } ),
	Action('e', "enable" , "enable"       , function(string[] args) { EnableWindow(parseHwnd(args[0]), TRUE   ); return string.init; } ),
	Action('d', "disable", "disable"      , function(string[] args) { EnableWindow(parseHwnd(args[0]), FALSE  ); return string.init; } ),
	Action('m', "move"   , "move to (0,0)", function(string[] args) { MoveWindowTo00(parseHwnd(args[0])       ); return string.init; } ),
];

string buildHtml()
{
	StringBuilder sb;
	sb.put(q"EOF
<!DOCTYPE html>

<style>
body {
	font-family: monospace;
}

.window {
	margin-left: 24px;
	white-space: pre;
}
</style>

EOF");

	static HWND fg;
	fg = GetForegroundWindow();

	static void dumpWindow(ref StringBuilder sb, HWND h)
	{
		sb.put(`<div class="window">`);

		static void writeFlag(ref StringBuilder sb, char c, string description, bool value)
		{
			/*
			if (value)
				sb.put(`<span class="yes" title="`~description~`">`~c~`</span>`);
			else
				sb.put(`<span class="no"  title="not `~description~`">&nbsp;</span>`);
			*/
			sb.put(value ? c : ' ');
		}

		writeFlag(sb, '*', "foreground window", h==fg);
		writeFlag(sb, '+', "visible", !!IsWindowVisible(h));
		writeFlag(sb, '-', "disabled", !IsWindowEnabled(h));
		static char[8] hs;
		toHex(cast(uint)h, hs);
		sb.put(' ', hs, ' ');

		static char[256] bText, bClass;
		auto sText  = bText [0..GetWindowText(h, bText .ptr, bText .length)];
		auto sClass = bClass[0..GetClassName (h, bClass.ptr, bClass.length)];
		RECT r;
		GetWindowRect(h, &r);
		if (sText.length)
			sb.put(sText, " : ");
		sb.put(sClass, format(" (%d,%d - %d,%d)", r.left, r.top, r.right, r.bottom));
		sb.put(` [`);
		foreach (action; actions)
			sb.put(`<a href="/`, action.name, `/`, hs, `" title="`, action.description, `">`, action.link, `</a>`);
		sb.put(`]`);

  		HWND c = FindWindowEx(h, null, null, null);
  		while (c)
  		{
  			dumpWindow(sb, c);
			c = FindWindowEx(h, c, null, null);
  		}

		sb.put(`</div>`);
	}

	dumpWindow(sb, null);
	return sb.get();
}

void main()
{
	void onRequest(HttpRequest request, HttpServerConnection conn)
	{
		auto response = new HttpResponseEx();
		scope(exit) conn.sendResponse(response);

		try
		{
			enforce(request.resource.startsWith('/'), "Invalid path");
			auto segments = request.resource.split("/");

			if (segments[1] == "") // index
			{
				enforce(segments.length == 2);
				response.serveData(buildHtml());
				return;
			}

			foreach (action; actions)
				if (segments[1] == action.name)
				{
					action.f(segments[2..$]);
					response.redirect("/");
					return;
				}

			throw new Exception("Unknown resource");
		}
		catch (Exception e)
		{
			response.serveText(e.msg);
			response.setStatus(HttpStatusCode.InternalServerError);
		}
	}

	auto server = new HttpServer();
	server.log = new ConsoleLogger("HTTP");
	server.handleRequest = &onRequest;
	server.listen(58094);

	socketManager.loop();
}

HWND parseHwnd(string str) { return cast(HWND)to!uint(str, 16); }

void MoveWindowTo00(HWND h)
{
	RECT r;
	GetWindowRect(h, &r);
	MoveWindow(h, 0, 0, r.right-r.left, r.bottom-r.top, TRUE);
}
