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

import de.polygonal.zz.controller.SpriteSheetController.SheetAnimation;
import de.polygonal.zz.data.Animation.AnimationFrame;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;
import haxe.Json;

using Reflect;

/**
	Creates a texture atlas from a TexturePacker JSON-Array file (https://www.codeandweb.com/texturepacker).
**/
class TpJsonArrayFormat implements TextureAtlasFormat
{
	public static function getSpriteSheetAnims(jsonString:String, holdTime:Float = 1 / 60):Array<SheetAnimation>
	{
		var output = [];
		
		var o:Dynamic = Json.parse(jsonString);
		var frames:Array<{filename:String}> = o.field("frames");
		var fileNames = Lambda.array(Lambda.map(frames, function(e) return e.filename));
		var ereg = ~/(.*?)[\/_](\d{4})$/;
		var currentAni:SheetAnimation = null, currentName = null, index = 0, frame = -1;
		for (i in fileNames)
		{
			var matched = ereg.match(i);
			
			if (!matched)
			{
				index++;
				continue;
			}
			
			var name = ereg.matched(1);
			if (currentName != name)
			{
				if (currentAni != null)
					output.push(currentAni);
				currentName = name;
				frame = Std.parseInt(ereg.matched(2));
				currentAni = new SheetAnimation(name, false, []);
			}
			else
			{
				frame++;
				assert(frame == Std.parseInt(ereg.matched(2)));
			}
			
			currentAni.frames.push(new AnimationFrame<String>(i, holdTime));
			index++;
		}
		
		if (currentAni != null) output.push(currentAni);
		return output;
	}
	
	var mJsonString:String;
	
	public function new(jsonString:String)
	{
		mJsonString = jsonString;
	}
	
	public function getAtlas():TextureAtlasDef 
	{
		var data = new TextureAtlasDef();
		
		var o:Dynamic = Json.parse(mJsonString);
		
		var meta:Dynamic = Reflect.field(o, "meta");
		data.size.x = meta.field("size").field("w");
		data.size.y = meta.field("size").field("h");
		data.scale = cast meta.field("scale");
		
		var index = 0;
		var frames:Array<Dynamic> = o.field("frames");
		for (i in frames)
		{
			var f = new TextureAtlasFrameDef(), t:Dynamic;
			data.frames.push(f);
			
			f.id = index++;
			f.name = i.field("filename");
			
			t = i.field("frame");
			f.cropRect.x = t.field("x");
			f.cropRect.y = t.field("y");
			f.cropRect.w = t.field("w");
			f.cropRect.h = t.field("h");
			f.trimFlag = i.field("trimmed");
			
			t = i.field("sourceSize");
			f.sourceSize.x = t.field("w");
			f.sourceSize.y = t.field("h");
			
			t = i.field("spriteSourceSize");
			f.trimOffset.x = t.field("x");
			f.trimOffset.y = t.field("y");
		}
		
		return data;
	}
}