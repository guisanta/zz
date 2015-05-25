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
package de.polygonal.zz.render.platform.flash.stage3d.painter;

/*enum PainterFeature
{
	Texture;
	PremultipliedTexture;
	Color;
	Alpha;
	ColorTransform;
	Batching;
	Compressed;
	CompressedAlpha;
}*/

@:build(de.polygonal.core.macro.IntConsts.build(
[
	PAINTER_FEATURE_TEXTURE,
	PAINTER_FEATURE_TEXTURE_PMA,
	PAINTER_FEATURE_COLOR,
	PAINTER_FEATURE_ALPHA,
	PAINTER_FEATURE_COLOR_TRANSFORM,
	PAINTER_FEATURE_BATCHING
	
	#if flash
	,
	PAINTER_FEATURE_COMPRESSED,
	PAINTER_FEATURE_COMPRESSED_ALPHA
	#end
], true, true))
class PainterFeature
{
	inline public static function supportsAlpha(code:Int):Bool return code & PAINTER_FEATURE_ALPHA > 0;
	
	inline public static function supportsColorTransform(code:Int):Bool return code & PAINTER_FEATURE_COLOR_TRANSFORM > 0;
	
	inline public static function supportsTexture(code:Int):Bool return code & (PAINTER_FEATURE_TEXTURE | PAINTER_FEATURE_TEXTURE_PMA) > 0;
	
	inline public static function supportsTextureStraightAlpha(code:Int):Bool return code & PAINTER_FEATURE_TEXTURE > 0;
	
	inline public static function supportsTexturePremultipliedAlpha(code:Int):Bool return code & PAINTER_FEATURE_TEXTURE_PMA > 0;
	
	public static function print(bits:Int):String
	{
		var a = [];
		if (bits & PAINTER_FEATURE_TEXTURE > 0) a.push("texture-straight");
		if (bits & PAINTER_FEATURE_TEXTURE_PMA > 0) a.push("texture-pma");
		if (bits & PAINTER_FEATURE_COLOR > 0) a.push("color");
		if (bits & PAINTER_FEATURE_ALPHA > 0) a.push("alpha");
		if (bits & PAINTER_FEATURE_COLOR_TRANSFORM > 0) a.push("colortransform");
		if (bits & PAINTER_FEATURE_BATCHING > 0) a.push("batching");
		if (bits & PAINTER_FEATURE_COMPRESSED > 0) a.push("compressed");
		if (bits & PAINTER_FEATURE_COMPRESSED_ALPHA > 0) a.push("compressed-alpha");
		return a.join(",");
	}
}