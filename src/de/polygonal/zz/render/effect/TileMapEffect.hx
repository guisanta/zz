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
package de.polygonal.zz.render.effect;

import de.polygonal.core.math.Limits;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.ds.Array2;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.Texture;

class TileMapEffect extends Effect
{
	inline public static var TYPE = 3;
	
	public var texture:Texture;
	
	public var atlas(default, null):TextureAtlas;
	
	public var screenTiles(default, null):Array2<Int>;
	public var tileSize(default, null):Int;
	
	public var numVisTilesX(default, null):Int;
	public var numVisTilesY(default, null):Int;
	
	public var redraw(default, null):Bool;
	public var sizeChanged(default, null):Bool;
	
	public var smooth:Bool = true;
	
	public var parallax:Float = 1;
	
	var mMinIx0:Int = Limits.INT16_MIN;
	var mMinIy0:Int = Limits.INT16_MIN;
	var mMaxIx0:Int = Limits.INT16_MIN;
	var mMaxIy0:Int = Limits.INT16_MIN;
	
	var mMinIx1:Int = 0;
	var mMinIy1:Int = 0;
	var mMaxIx1:Int = 0;
	var mMaxIy1:Int = 0;
	
	var mNumTilesX = -1;
	var mNumTilesY = -1;
	
	var mTiles:Array2<Int>;
	
	public function new(tiles:Array2<Int>, tileSize:Int, texture:Texture, atlas:TextureAtlas) 
	{
		super(TYPE);
		
		mTiles = tiles;
		
		this.tileSize = tileSize;
		this.texture = texture;
		this.atlas = atlas;
		
		screenTiles = new Array2<Int>(32, 32);
	}
	
	override public function draw(renderer:Renderer)
	{
		var c = renderer.getCamera();
		
		var invTileSize = 1 / tileSize;
		var sizeX = c.sizeX / c.zoom;
		var sizeY = c.sizeY / c.zoom;
		
		var scrollX:Float, scrollY:Float;
		
		if (c.rotation == 0)
		{
			numVisTilesX = Math.ceil(sizeX * invTileSize) + 2;
			numVisTilesY = Math.ceil(sizeY * invTileSize) + 2;
			
			scrollX = c.centerX - sizeX / 2;
			scrollY = c.centerY - sizeY / 2;
		}
		else
		{
			var rx = sizeX / 2;
			var ry = sizeY / 2;
			
			var ux, uy;
			var angle = c.rotation * M.DEG_RAD;
			
			ux = Math.cos(angle);
			uy = Math.sin(angle);
			var maxX = Limits.FLOAT_MIN;
			maxX = M.fmax(maxX, -rx * ux - ry * uy);
			maxX = M.fmax(maxX,  rx * ux - ry * uy);
			maxX = M.fmax(maxX, -rx * ux + ry * uy);
			maxX = M.fmax(maxX,  rx * ux + ry * uy);
			
			ux =-Math.sin(angle);
			uy = Math.cos(angle);
			var maxY = Limits.FLOAT_MIN;
			maxY = M.fmax(maxY, -rx * ux - ry * uy);
			maxY = M.fmax(maxY,  rx * ux - ry * uy);
			maxY = M.fmax(maxY, -rx * ux + ry * uy);
			maxY = M.fmax(maxY,  rx * ux + ry * uy);
			
			numVisTilesX = Math.ceil(maxX * 2 * invTileSize) + 2;
			numVisTilesY = Math.ceil(maxY * 2 * invTileSize) + 2;
			
			scrollX = c.centerX - maxX;
			scrollY = c.centerY - maxY;
		}
		
		if (numVisTilesX != mNumTilesX || numVisTilesY != mNumTilesY)
		{
			redraw = true;
			sizeChanged = true;
			
			mNumTilesX = numVisTilesX;
			mNumTilesY = numVisTilesY;
			screenTiles.resize(numVisTilesX, numVisTilesY);
		}
		
		var a = mTiles;
		
		var scrollFactor = parallax - 1;
		
		var sX = scrollX + scrollX * scrollFactor;
		var sY = scrollY + scrollY * scrollFactor;
		
		mMinIx1 = Std.int(sX * invTileSize) - 1;
		mMinIy1 = Std.int(sY * invTileSize) - 1;
		mMaxIx1 = Std.int((sX + sizeX) * invTileSize) + 1;
		mMaxIy1 = Std.int((sY + sizeY) * invTileSize) + 1;
		
		if (mMinIx1 != mMinIx0 || mMinIy1 != mMinIy0 || mMaxIx1 != mMaxIx0 || mMaxIy1 != mMaxIy0 || redraw)
		{
			for (y in 0...screenTiles.rows)
			{
				for (x in 0...screenTiles.cols)
				{
					var gid =
						if (a.inRange(mMinIx1 + x, mMinIy1 + y))
							a.get(mMinIx1 + x, mMinIy1 + y);
						else
							-1;
					screenTiles.set(x, y, gid);
				}
			}
			
			mMinIx0 = mMinIx1;
			mMinIy0 = mMinIy1;
			mMaxIx0 = mMaxIx1;
			mMaxIy0 = mMaxIy1;
			
			redraw = true;
		}
		
		var world = renderer.currentVisual.world;
		var t = world.getTranslate();
		world.setTranslate2(mMinIx1 * tileSize - scrollFactor * scrollX, mMinIy1 * tileSize - scrollFactor * scrollY);
		
		var tmp = renderer.smooth;
		
		renderer.smooth = smooth;
		renderer.drawTileMapEffect(this);
		renderer.smooth = tmp;
		
		redraw = false;
		sizeChanged = false;
	}
}