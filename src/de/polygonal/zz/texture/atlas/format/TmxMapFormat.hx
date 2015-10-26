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
import de.polygonal.core.math.Rect.Recti;
import de.polygonal.ds.Array2;
import de.polygonal.ds.Array2.Array2Cell;
import de.polygonal.ds.ArrayConvert;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasFrameDef;
import de.polygonal.zz.tiled.TmxFile.TmxData;
import haxe.ds.IntMap;

/**
	Creates a texture atlas from a TMX map file (https://github.com/bjorn/tiled/wiki/TMX-Map-Format).
**/
class TmxMapFormat implements TextureAtlasFormat
{
	var mTmxData:TmxData;
	
	public function new(tmxData:TmxData) 
	{
		mTmxData = tmxData;
	}
	
	public function getAtlas():TextureAtlasDef 
	{
		var map = mTmxData;
		
		var tileSize = new Sizei(map.tileWidth, map.tileHeight);
		
		var tileset = map.tilesets[0]; //TODO support multiple tilesets
		
		var margin = tileset.margin;
		var spacing = tileset.spacing;
		
		var imageSize = new Sizei(tileset.image.width, tileset.image.height);
		
		var rows = Std.int(imageSize.y / (tileSize.x + 2 * margin));
		var cols = Std.int(imageSize.x / (tileSize.y + 2 * margin));
		
		var tmp = new Array2<Int>(cols, rows);
		var tmpCell = new Array2Cell();
		
		function getCropRect(gid:Int):Recti
		{
			gid--;
			tmp.indexToCell(gid, tmpCell);
			var x = tmpCell.x * (tileSize.x + spacing) + margin;
			var y = tmpCell.y * (tileSize.y + spacing) + margin;
			return new Recti(x, y, tileSize.x, tileSize.y);
			
			//TODO bleed useful?, margin, spacing
			//var x = tmpCell.x * (tileSize.x + spacing) + 0;
			//var y = tmpCell.y * (tileSize.y + spacing) + 0;
			//return new Recti(x, y, tileSize.x + spacing, tileSize.y + spacing);
		}
		
		var gids = new IntMap<Bool>();
		var frames:Array<TextureAtlasFrameDef> = [];
		
		for (layer in tileset.layers)
		{
			var tiles:Array2<Int> = ArrayConvert.toArray2(layer.data, map.width, map.height);
			tiles.iter(
				function(gid:Int, x:Int, y:Int):Int
				{
					if (gid == 0) return gid;
					
					if (gids.exists(gid)) return gid;
					gids.set(gid, true);
					
					var cropRect = getCropRect(gid);
					var size = new Sizei(cropRect.w, cropRect.h);
					frames.push
					({
						index: gid,
						name: 'gid_$gid',
						cropRect: cropRect,
						trimFlag: false,
						untrimmedSize: size,
						trimOffset: new Coord2i()
					});
					
					return gid;
				});
		}
		
		return {size: imageSize, scale: 1., frames: frames};
	}
}