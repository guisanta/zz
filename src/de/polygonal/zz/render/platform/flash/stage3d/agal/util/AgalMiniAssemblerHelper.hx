/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.render.platform.flash.stage3d.agal.util;

import flash.utils.RegExp;
import haxe.ds.StringMap;

class AgalMiniAssemblerHelper
{
	static var regExpCache:StringMap<RegExp> = new StringMap<RegExp>();
	
	inline public static function replace(s:String, pattern:String, ?flags = "", x:String):String
		return untyped s.replace(getRegExp(pattern, flags), x);
	
	inline public static function search(s:String, pattern:String, ?flags = ""):Int
		return untyped s.search(getRegExp(pattern, flags));
	
	inline public static function match(s:String, pattern:String, ?flags = ""):Array<String>
		return untyped s.match(getRegExp(pattern, flags));
	
	inline public static function slice(s:String, start:Int, end = 0x7FFFFFFF):String
		return untyped s.slice(start, end == 0x7FFFFFFF ? s.length : end);
	
	inline static function getRegExp(pattern:String, flags:String)
	{
		var regExp = regExpCache.get(pattern + flags);
		if (regExp == null)
		{
			regExp = new flash.utils.RegExp(pattern, flags);
			regExpCache.set(pattern + flags, regExp);
		}
		return regExp;
	}
}