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
package de.polygonal.zz.tiled;

import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.ArrayConvert;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.texture.TextureLib;
import de.polygonal.zz.tiled.TmxFile.TmxData;

class TmxTileMap
{
	public var visual(default, null):Quad;
	
	public function new(textureId:Int, tmxData:TmxData, layerName:String)
	{
		visual = new Quad();
		
		//TODO support multiple tilesets
		var layer = null;
		for (i in tmxData.tilesets[0].layers)
		{
			if (i.name == layerName)
			{
				layer = i;
				break;
			}
		}
		
		assert(layer != null);
		
		var tiles = ArrayConvert.toArray2(layer.data, tmxData.width, tmxData.height);
		var tileSize = tmxData.tileWidth;
		
		var tilesetTexture = TextureLib.getTexture(textureId);
		
		visual.effect = new TileMapEffect(tiles, tileSize, tilesetTexture, tilesetTexture.atlas);
	}
	
	public var parallax(get, set):Float;
	function get_parallax():Float
	{
		return cast(visual.effect, TileMapEffect).parallax;
	}
	function set_parallax(value:Float):Float
	{
		if (value < 0) value = 0;
		cast(visual.effect, TileMapEffect).parallax = value;
		return value;
	}
	
	public var smooth(get, set):Bool;
	function get_smooth():Bool return cast(visual.effect, TileMapEffect).smooth;
	function set_smooth(value:Bool):Bool
	{
		cast(visual.effect, TileMapEffect).smooth = value;
		return value;
	}
	
	public var visible(get, set):Bool;
	function get_visible():Bool
	{
		return visual.cullingMode == CullingMode.CullNever;
	}
	function set_visible(value:Bool):Bool
	{
		visual.cullingMode = value ? CullingMode.CullNever : CullingMode.CullAlways;
		return value;
	}
}