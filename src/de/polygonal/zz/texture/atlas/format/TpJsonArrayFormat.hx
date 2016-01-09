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
package de.polygonal.zz.texture.atlas.format;

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Recti;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;
import haxe.Json;

private typedef SizeDef = { w:Int, h:Int };
private typedef RectDef = { > SizeDef, x:Int, y:Int };
private typedef FrameDef =
{
	filename:String,
	frame:RectDef,
	rotated:Dynamic,
	trimmed:Bool,
	spriteSourceSize:RectDef,
	sourceSize:SizeDef
}
private typedef MetaDef = { size:SizeDef, scale:Float }

/**
	Creates a texture atlas from a TexturePacker JSON-Array file (https://www.codeandweb.com/texturepacker).
**/
class TpJsonArrayFormat implements TextureAtlasFormat
{
	var mStr:String;
	
	public function new(str:String)
	{
		mStr = str;
	}
	
	public function getAtlas():TextureAtlasDef 
	{
		var data:TextureAtlasDef = {size: new Sizei(), scale: 1., frames: []};
		
		var o:Dynamic = Json.parse(mStr);
		var meta:MetaDef = Reflect.field(o, "meta");
		
		data.size.x = meta.size.w;
		data.size.y = meta.size.h;
		data.scale = meta.scale;
		
		inline function toRect(o:RectDef):Recti return new Recti(o.x, o.y, o.w, o.h);
		
		var index = 0;
		var frames:Array<FrameDef> = Reflect.field(o, "frames");
		for (i in frames)
		{
			data.frames.push({
					index: index++,
					name: i.filename,
					cropRect: toRect(i.frame),
					trimFlag: i.trimmed,
					untrimmedSize: new Sizei(i.sourceSize.w, i.sourceSize.h),
					trimOffset: new Coord2i(i.spriteSourceSize.x, i.spriteSourceSize.y)
				});
		}
		
		return data;
	}
}