/*
Copyright (c) 2017 Michael Baczynski, http://www.polygonal.de

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
import de.polygonal.ds.Array2;
import de.polygonal.ds.Array2.Array2Cell;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasFrameDef;
import de.polygonal.zz.tiled.TmxFile.TmxData;

/**
	Creates a texture atlas from a TMX tileset (https://github.com/bjorn/tiled/wiki/TMX-Map-Format).
**/
class TiledTmxFormat implements TextureAtlasFormat
{
	var mTmxData:TmxData;
	var mTilesetIndex:Int;
	
	public function new(tmxData:TmxData, tilesetIndex:Int)
	{
		assert(tilesetIndex >= 0 && tilesetIndex < tmxData.tilesets.length);
		mTilesetIndex = tilesetIndex;
		mTmxData = tmxData;
	}
	
	public function getAtlas():TextureAtlasDef
	{
		var tileset = mTmxData.tilesets[mTilesetIndex];
		var tw = tileset.tileWidth;
		var th = tileset.tileHeight;
		var iw = tileset.image.width;
		var ih = tileset.image.height;
		var margin = tileset.margin;
		var spacing = tileset.spacing;
		var tws = tw + spacing;
		var ths = th + spacing;
		
		var h1 = ih - (2 * (margin + th) + spacing);
		var rows = h1 == 0 ? 2 : (h1 < 0 ? 1 : Std.int(h1 / ths) + 2);
		
		var w1 = iw - (2 * (margin + tw) + spacing);
		var cols = w1 == 0 ? 2 : (w1 < 0 ? 1 : Std.int(w1 / tws) + 2);
		
		var tmp = new Array2<Int>(cols, rows);
		var tmpCell = new Array2Cell();
		
		inline function getCropRect(gid:Int):Recti
		{
			tmp.indexToCell(gid, tmpCell);
			var x = margin + tmpCell.x * tws;
			var y = margin + tmpCell.y * ths;
			return new Recti(x, y, tw, th);
		}
		
		var data = new TextureAtlasDef();
		data.size.x = iw;
		data.size.y = ih;
		var first = tileset.firstGid;
		var frames = data.frames;
		var x, y;
		for (row in 0...rows)
		{
			for (col in 0...cols)
			{
				x = margin + col * tws;
				y = margin + row * ths;
				var r = new Recti(x, y, tw, th);
				var gid = (row * cols + col) + first;
				var f = new TextureAtlasFrameDef();
				f.id = gid;
				f.name = Std.string(gid);
				f.cropRect = r;
				f.sourceSize.x = r.w;
				f.sourceSize.y = r.h;
				frames.push(f);
			}
		}
		return data;
	}
}