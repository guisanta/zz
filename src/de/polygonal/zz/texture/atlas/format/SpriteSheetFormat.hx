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
	
	public function new(width:Int, height:Int, rows:Int, cols:Int, name:String)
	{
		assert(width % cols == 0);
		assert(height % rows == 0);
		
		mData = {size: new Sizei(width, height), scale: 1., frames: []};
		
		var frameW = Std.int(width / cols);
		var frameH = Std.int(height / rows);
		
		var index = 0;
		for (y in 0...rows)
		{
			for (x in 0...cols)
			{
				mData.frames.push
				({
					index: index,
					name: '$name$index',
					cropRect: new Recti(x * frameW, y * frameH, frameW, frameH),
					trimFlag: false,
					untrimmedSize: new Sizei(frameW, frameH),
					trimOffset: new Coord2i(0, 0)
				});
				index++;
			}
		}
	}
	
	public function getAtlas():TextureAtlasDef 
	{
		return mData;
	}
}