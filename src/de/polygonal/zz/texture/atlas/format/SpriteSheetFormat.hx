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

import de.polygonal.core.math.Recti;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;

/**
	Simple sprite sheet format (rows * cols).
**/
class SpriteSheetFormat implements TextureAtlasFormat
{
	var mData:TextureAtlasDef;
	
	public function new(width:Int, height:Int, rows:Int, cols:Int, frameName:String)
	{
		assert(width % cols == 0);
		assert(height % rows == 0);
		
		mData = new TextureAtlasDef();
		mData.size.set(width, height);
		
		var frameW = Std.int(width / cols);
		var frameH = Std.int(height / rows);
		
		inline function pad(index:Int):String
		{
			var s = "";
			if (index <   10) s += "0";
			if (index <  100) s += "0";
			if (index < 1000) s += "0";
			return s + index;
		}
		
		var index = 0;
		for (y in 0...rows)
		{
			for (x in 0...cols)
			{
				var frame = new TextureAtlasFrameDef();
				
				frame.id = index;
				frame.name = frameName + pad(index);
				frame.cropRect = new Recti(x * frameW, y * frameH, frameW, frameH);
				frame.sourceSize.set(frameW, frameH);
				mData.frames.push(frame);
				index++;
			}
		}
	}
	
	public function getAtlas():TextureAtlasDef 
	{
		return mData;
	}
}