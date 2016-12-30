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
package de.polygonal.zz.render.platform.flash.legacy;

import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Vec3;
import de.polygonal.ds.IntHashTable;
import de.polygonal.zz.data.ColorTransform;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import de.polygonal.zz.scene.Xform;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.Shape;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

import flash.geom.ColorTransform in FlashColorTransform;

/**
	A renderer that uses the `flash.display.BitmapData` API.
**/
class BitmapDataRenderer extends Renderer
{
	var mContext:BitmapData;
	
	var mTmpRect:Rectangle;
	var mTmpMatrix:Matrix;
	var mTmpColorTransform:FlashColorTransform;
	var mTmpColorTransformAlpha:FlashColorTransform;
	var mTmpPoint:Point;
	var mTmpShape:Shape;
	var mTmpMat44:Mat44;
	
	var mTileLookup:IntHashTable<Tile>;
	var mCurrentBlendMode:BlendMode;
	var mScratchShape:Shape;
	
	var mTileMapCanvas:BitmapData;
	var mTileMapCanvasLut:IntHashTable<BitmapData>;
	
	public function new()
	{
		super();
		
		supportsNonPowerOfTwoTextures = true;
		
		mTmpRect = new Rectangle();
		mTmpMatrix = new Matrix();
		mTmpColorTransform = new FlashColorTransform();
		mTmpColorTransformAlpha = new FlashColorTransform();
		mTmpPoint = new Point();
		mTmpShape = new Shape();
		mTileLookup = new IntHashTable<Tile>(512, 512);
		
		mTmpMat44 = new Mat44();
	}
	
	override public function free()
	{
		super.free();
		
		mContext = null;
		mTmpRect = null;
		mTmpMatrix = null;
		mTmpColorTransform = null;
		mTmpColorTransformAlpha = null;
		mTmpPoint = null;
		mTmpShape = null;
		
		for (i in mTileLookup)
		{
			i.data.dispose();
			i.data = null;
			i.rect = null;
		}
		mTileLookup.free();
		mTileLookup = null;
		
		if (mTileMapCanvasLut != null)
		{
			for (i in mTileMapCanvasLut) i.dispose();
			mTileMapCanvasLut.free();
			mTileMapCanvas = null;
		}
	}
	
	override function onInitRenderContext(handle:Dynamic)
	{
		assert(Std.is(handle, BitmapData), "invalid context: flash.display.BitmapData required");
		
		mContext = flash.Lib.as(handle, BitmapData);
	}
	
	override function onTargetResize(width:Int, height:Int)
	{
		mContext = cast getRenderTarget().getContext();
		super.onTargetResize(width, height);
	}
	
	override function clear()
	{
		var target = getRenderTarget();
		if (target == null || mContext == null) return;
		
		mContext.fillRect(mContext.rect, target.color);
	}
	
	override function onBeginScene()
	{
		super.onBeginScene();
		mContext.lock();
	}
	
	override function onEndScene()
	{
		mContext.unlock();
		
		super.onEndScene();
	}
	
	override function viewportTransform(output:Vec3)
	{
		var target = getRenderTarget();
		if (target.hasViewport())
		{
			var size = target.getSize();
			var viewport = target.getViewport();
			output.x = size.x * viewport.x + viewport.w * output.x;
			output.y = size.y * viewport.y + viewport.h * output.y;
		}
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		var w = currentVisual.world;
		var s = w.getScale();
		var t = w.getTranslate();
		
		var shape = mScratchShape;
		if (shape == null) shape = mScratchShape = new Shape();
		
		var g = shape.graphics;
		g.clear();
		g.beginFill(effect.color, 1);
		g.drawRect(0, 0, s.x, s.y);
		g.endFill();
		
		var flashMatrix = transformationToMatrix(w, s.x, s.y, mTmpMatrix);
		var flashColorTransform = getColorTransform(effect);
		mContext.draw(shape, flashMatrix, flashColorTransform, mCurrentBlendMode, null, smooth);
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		var uv = effect.cropRectPx;
		
		var w = uv.w;
		var h = uv.h;
		
		var key = effect.getFrameId() << 16 | effect.texture.key;
		var tile = mTileLookup.get(key);
		if (tile == null)
		{
			//create bitmap tile and cache it for repeated use
			mTmpRect.x = uv.x;
			mTmpRect.y = uv.y;
			mTmpRect.width = w;
			mTmpRect.height = h;
			mTmpPoint.x = 0;
			mTmpPoint.y = 0;
			
			var bmd = new BitmapData(w, h, true, 0);
			bmd.copyPixels(effect.texture.imageData, mTmpRect, mTmpPoint);
			
			tile = new Tile();
			tile.data = bmd;
			tile.rect = bmd.rect.clone();
			
			mTileLookup.set(key, tile);
		}
		
		var world = currentVisual.world;
		var s = world.getScale();
		var t = world.getTranslate();
		
		var flashMatrix = transformationToMatrix(world, w, h, mTmpMatrix);
		var flashColorTransform = getColorTransform(effect);
		mContext.draw(tile.data, flashMatrix, flashColorTransform, mCurrentBlendMode, null, smooth);
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
		var world = currentVisual.world;
		
		var bmd = effect.texture.imageData;
		
		if (mTileMapCanvasLut == null)
			mTileMapCanvasLut = new IntHashTable<BitmapData>(64);
			
		var canvas = mTileMapCanvasLut.get(effect.key);
		
		if (canvas == null || effect.sizeChanged)
		{
			var size = getCamera().getSize();
			
			if (canvas != null) canvas.dispose();
			
			var w = effect.numVisTilesX * effect.tileSize;
			var h = effect.numVisTilesY * effect.tileSize;
			canvas = new BitmapData(w, h, true, 0);
			
			mTileMapCanvasLut.unset(effect.key);
			mTileMapCanvasLut.set(effect.key, canvas);
		}
		
		if (effect.redraw)
		{
			var t = effect.screenTiles;
			var p = mTmpPoint;
			var r = mTmpRect;
			var s = effect.tileSize;
			var atlas = effect.atlas;
			
			canvas.lock();
			for (y in 0...t.rows)
			{
				for (x in 0...t.cols)
				{
					var gid = t.get(x, y);
					if (gid > 0)
					{
						var uv = atlas.getFrameById(gid).texCoordPx;
						r.x = uv.x;
						r.y = uv.y;
						r.width = uv.w;
						r.height = uv.h;
						p.x = x * s;
						p.y = y * s;
						canvas.copyPixels(bmd, r, p);
					}
					else
					{
						r.x = x * s;
						r.y = y * s;
						r.width = s;
						r.height = s;
						canvas.fillRect(r, 0);
					}
				}
			}
			canvas.unlock();
		}
		
		var flashMatrix = transformationToMatrix(world, 1, 1, mTmpMatrix);
		
		var flashColorTransform = getColorTransform(effect);
		mContext.draw(canvas, flashMatrix, flashColorTransform, smooth);
	}
	
	override function getProjectionMatrix():Mat44
	{
		var c = getCamera();
		if (c == null)
		{
			mProjMatrix.setAsIdentity();
			return mProjMatrix;
		}
		
		//shift to top-left corner
		mProjMatrix.setAsTranslate(c.sizeX / 2, c.sizeY / 2, 0);
		
		//when the window is resized, everything is squeezed/stretched to the new size
		var target = getRenderTarget();
		var viewport = target.getPixelViewport();
		var sizeX = viewport.w;
		var sizeY = viewport.h;
		
		var r = target.internalResolution;
		if (r != null)
		{
			sizeX = r.x;
			sizeY = r.y;
		}
		
		mProjMatrix.catScale(sizeX / c.sizeX, sizeY / c.sizeY, 1);
		
		return mProjMatrix;
	}
	
	override public function setAlphaBlendState(value:AlphaBlendMode)
	{
		mCurrentBlendMode =
		switch (value)
		{
			case AlphaBlendMode.Normal: BlendMode.NORMAL;
			case AlphaBlendMode.Add: BlendMode.ADD;
			case AlphaBlendMode.Screen: BlendMode.SCREEN;
			case AlphaBlendMode.Multiply: BlendMode.MULTIPLY;
			case AlphaBlendMode.None: null;
			case AlphaBlendMode.User(_, _): throw "unsupported blend mode";
		}
	}
	
	override function screenToCanonicalViewVolume(x:Int, y:Int, output:Vec3)
	{
		var target = getRenderTarget();
		var viewport = target.getPixelViewport();
		
		output.set
		(
			x - viewport.x,
			y - viewport.y,
			1
		);
		
		var r = target.internalResolution;
		if (r != null)
		{
			output.x /= viewport.w / r.x;
			output.y /= viewport.h / r.y;
		}
	}
	
	inline function transformationToMatrix(xf:Xform, w:Float, h:Float, out:Matrix):Matrix
	{
		assert(xf.isRSMatrix());
		
		var s = xf.getScale();
		var r = xf.getRotate();
		var t = xf.getTranslate();
		var sx = (s.x / w);
		var sy = (s.y / h);
		
		if (getCamera() == null)
		{
			out.a = sx * r.m11;
			out.b = sx * r.m21;
			out.c = sy * r.m12;
			out.d = sy * r.m22;
			out.tx = t.x;
			out.ty = t.y;
		}
		else
		{
			var mvp = currentMvp;
			var m = mTmpMat44;
			m.m11 = sx * r.m11;
			m.m21 = sx * r.m21;
			m.m12 = sy * r.m12;
			m.m22 = sy * r.m22;
			m.tx = t.x;
			m.ty = t.y;
			
			Mat44.affineMatrixProduct2d(currentViewProjMat, m, mvp);
			
			out.a = mvp.m11;
			out.b = mvp.m21;
			out.c = mvp.m12;
			out.d = mvp.m22;
			out.tx = mvp.tx;
			out.ty = mvp.ty;
		}
		
		return out;
	}
	
	inline function getColorTransform(effect:Effect):FlashColorTransform
	{
		var out = null;
		
		//TODO handle color transformation
		//out.concat(toFlashColorTransform(effect.colorTransform, mTmpColorTransform));
		
		if (currentAlphaMultiplier < 1)
		{
			out = mTmpColorTransformAlpha;
			out.alphaMultiplier = currentAlphaMultiplier;
		}
		
		return out;
	}
	
	inline function toFlashColorTransform(value:ColorTransform, output:FlashColorTransform):FlashColorTransform
	{
		var o;
		
		o = value.multiplier;
		output.redMultiplier = o.r;
		output.greenMultiplier = o.g;
		output.blueMultiplier = o.b;
		output.alphaMultiplier = o.a * currentAlphaMultiplier;
		
		o = value.offset;
		output.redOffset = o.r;
		output.greenOffset = o.g;
		output.blueOffset = o.b;
		output.alphaOffset = o.a;
		
		return output;
	}
}

private class Tile
{
	public var data:BitmapData;
	public var rect:Rectangle;
	
	public function new() {}
}