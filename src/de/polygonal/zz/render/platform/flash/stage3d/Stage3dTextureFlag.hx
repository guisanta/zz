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
package de.polygonal.zz.render.platform.flash.stage3d;

@:build(de.polygonal.core.macro.IntConsts.build(
[
	MM_NONE, MM_NEAREST, MM_LINEAR,
	FM_NEAREST, FM_LINEAR,
	REPEAT_NORMAL, REPEAT_CLAMP,
	DXT1, DXT5
], true, true))
class Stage3dTextureFlag
{
	static var MAX = 9;
	
	inline public static var PRESET_QUALITY_LOW    = MM_NONE    | FM_NEAREST | REPEAT_NORMAL;
	inline public static var PRESET_QUALITY_MEDIUM = MM_NONE    | FM_LINEAR  | REPEAT_NORMAL;
	inline public static var PRESET_QUALITY_HIGH   = MM_NEAREST | FM_LINEAR  | REPEAT_NORMAL;
	inline public static var PRESET_QUALITY_ULTRA  = MM_LINEAR  | FM_LINEAR  | REPEAT_NORMAL;
	
	public static function print(flags:Int):String
	{
		if (flags <= 0) return "-";
		
		var names = ["mipnone", "mipnearest", "miplinear", "nearest", "linear", "repeat", "clamp", "dxt1", "dxt5"];
		
		var a = [];
		for (i in 0...MAX)
			if (flags & (1 << i) > 0)
				a.push(i >= MAX ? "?" : names[i]);
		return a.join(",");
	}
}