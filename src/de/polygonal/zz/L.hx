package de.polygonal.zz;

#if log
import de.polygonal.core.log.Log;
import de.polygonal.sys.LogSystem;
import de.polygonal.core.log.LogLevel;
class L
{
	static var _log:Log;
	public static var log(get, never):Log;
	static function get_log():Log
	{
		if (_log == null) _log = LogSystem.getLog("zz", true);
		return _log;
	}
	
	public static inline function v(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.v(msg, tag, posInfos);
	public static inline function d(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.d(msg, tag, posInfos);
	public static inline function i(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.i(msg, tag, posInfos);
	public static inline function w(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.w(msg, tag, posInfos);
	public static inline function e(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.e(msg, tag, posInfos);
}
#else
class L
{
	@:extern public static inline function v(x:Dynamic, ?tag:String) {}
	@:extern public static inline function d(x:Dynamic, ?tag:String) {}
	@:extern public static inline function i(x:Dynamic, ?tag:String) {}
	@:extern public static inline function w(x:Dynamic, ?tag:String) {}
	@:extern public static inline function e(x:Dynamic, ?tag:String) {}
}
#end