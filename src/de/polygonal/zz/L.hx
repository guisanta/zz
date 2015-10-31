package de.polygonal.zz;

import de.polygonal.core.log.Log;
import de.polygonal.core.log.LogSystem;

#if log
class L
{
	static var mLog:Log;
	public static var log(get_log, never):Log;
	static function get_log():Log
	{
		if (mLog == null) mLog = LogSystem.createLog("zz", true);
		return mLog;
	}
	
	inline public static function d(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.d(msg, tag, posInfos);
	inline public static function i(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.i(msg, tag, posInfos);
	inline public static function w(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.w(msg, tag, posInfos);
	inline public static function e(msg:Dynamic, ?tag:String, ?posInfos:haxe.PosInfos) log.e(msg, tag, posInfos);
}
#else
class L
{
	inline public static function d(x:Dynamic, ?tag:String) {}
	inline public static function i(x:Dynamic, ?tag:String) {}
	inline public static function w(x:Dynamic, ?tag:String) {}
	inline public static function e(x:Dynamic, ?tag:String) {}
}
#end