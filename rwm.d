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
		if (sText)
			sb.put(sText, " : ");
		sb.put(sClass/*, format(" (%d,%d - %d,%d)", r.left, r.top, r.right, r.bottom)*/);
		sb.put(` [`
			`<a href="/show/`, hs, `" title="show">s</a>`
			`<a href="/hide/`, hs, `" title="hide">h</a>`
			`<a href="/enable/`, hs, `" title="enable">e</a>`
			`<a href="/disable/`, hs, `" title="disable">d</a>`
			`]`
		);

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

HWND parseHwnd(string str)
{
	return cast(HWND)to!uint(str, 16);
}

void main()
{
	void onRequest(HttpRequest request, HttpServerConnection conn)
	{
		auto response = new HttpResponseEx();
		try
		{
			enforce(request.resource.startsWith('/'), "Invalid path");
			auto segments = request.resource.split("/");

			switch (segments[1])
			{
				case "": // index
					enforce(segments.length == 2);
					response.serveData(buildHtml());
					break;
				case "show":
					ShowWindow(parseHwnd(segments[2]), SW_SHOW);
					response.redirect("/"); break;
				case "hide":
					ShowWindow(parseHwnd(segments[2]), SW_HIDE);
					response.redirect("/"); break;
				case "enable":
					EnableWindow(parseHwnd(segments[2]), TRUE);
					response.redirect("/"); break;
				case "disable":
					EnableWindow(parseHwnd(segments[2]), FALSE);
					response.redirect("/"); break;
				default:
					throw new Exception("Unknown resource");
			}
		}
		catch (Exception e)
		{
			response.serveText(e.msg);
			response.setStatus(HttpStatusCode.InternalServerError);
		}
		conn.sendResponse(response);
	}

	auto server = new HttpServer();
	server.log = new ConsoleLogger("HTTP");
	server.handleRequest = &onRequest;
	server.listen(58094);

	socketManager.loop();
}
