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

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.time.Timebase;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Dll;
import de.polygonal.ds.DllNode;
import de.polygonal.ds.IntHashTable;
import de.polygonal.zz.data.ColorTransform;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.texture.*;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.AlphaBlendState;
import de.polygonal.zz.texture.Texture;
import flash.display.*;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

private typedef NativeColorTransform = flash.geom.ColorTransform;

/**
	Renders the scene by managing a flat display list of `flash.display.Bitmap` objects.
	
	_This technique is much faster than pure bitmap blitting, especially on older single-core CPUs._
**/
@:access(de.polygonal.zz.scene.Spatial)
class DisplayListRenderer extends Renderer
{
	var mContext:DisplayObjectContainer;
	
	var mBitmapDataLookup:IntHashTable<SpatialBitmapData>;
	var mBitmapLookup:IntHashTable<SpatialBitmap>;
	var mBitmapList:Dll<SpatialBitmap>;
	var mZIndex:Int;
	var mTmpMatrix:Matrix;
	var mTmpColorTransform:NativeColorTransform;
	var mTmpColorTransformAlpha:NativeColorTransform;
	var mTmpRect:Rectangle;
	var mTmpPoint:Point;
	
	var mCurrentBlendMode:BlendMode;
	
	var mPool:Array<SpatialBitmap>;
	
	var mModel:Mat44;
	
	var mTileMapCanvas:BitmapData;
	
	var mScratchShape:Shape;
	
	var mCleared = false;
	
	var mResized = false;
	var mCurrentColor:UInt = 0;
	
	public function new()
	{
		super();
		
		supportsNonPowerOfTwoTextures = true;
		
		mTmpMatrix = new Matrix();
		mTmpColorTransform = new NativeColorTransform();
		mTmpColorTransformAlpha = new NativeColorTransform();
		mTmpRect = new Rectangle();
		mTmpPoint = new Point(0, 0);
		mBitmapDataLookup = new IntHashTable<SpatialBitmapData>(1 << 16, 0xFFFF);
		mBitmapLookup = new IntHashTable<SpatialBitmap>(1 << 16, 0xFFFF);
		mBitmapList = new Dll<SpatialBitmap>();
		
		mCurrentBlendMode = BlendMode.NORMAL;
		
		mPool = new Array<SpatialBitmap>();
		
		mModel = new Mat44();
	}
	
	override public function free()
	{
		super.free();
		
		DisplayListUtil.removeChildren(mContext);
		
		mContext = null;
		
		for (i in mBitmapDataLookup) i.free();
		mBitmapDataLookup.free();
		mBitmapDataLookup = null;
		
		for (i in mBitmapLookup) i.free();
		mBitmapLookup.free();
		mBitmapLookup = null;
		
		mBitmapList.free();
		mBitmapList = null;
		
		mTmpMatrix = null;
		mTmpColorTransform = null;
		mTmpColorTransformAlpha = null;
		mTmpRect = null;
		mTmpPoint = null;
		mCurrentBlendMode = null;
	}
	
	/**
		Preallocates all atlas frames if a texture atlas is bound to `imageName`.
	**/
	public function preallocate(imageName:String)
	{
		throw 'todo';
		/*var atlas = RenderSystem.getAtlasByName(imageName);
		if (atlas != null)
		{
			var scratchEffect =new TextureEffect();
			for (i in 0...atlas.numFrames)
			{
				scratchEffect.setFrameIndex(i);
				
				var crop = atlas.getFrameAtIndex(i).texCoordPx;
				if (crop.w == 0 && crop.h == 0) continue; //SpriteText doesn't support character (index eq. charcode)
				
				var tex = scratchEffect.texture;
				getBitmapData(scratchEffect.getFrameIndex() << 16 | tex.key, tex, scratchEffect);
			}
		}*/
	}
	
	override function onInitRenderContext(value:Dynamic)
	{
		assert(Std.is(value, DisplayObjectContainer), "invalid context: flash.display.DisplayObjectContainer required");
		
		mContext = cast(value, DisplayObjectContainer);
	}
	
	override function onTargetResize(width:Int, height:Int)
	{
		mResized = true;
	}
	
	override function clear()
	{
		var target = getRenderTarget();
		if (target == null || mContext == null) return;
		
		var color = target.color;
		if (mResized || color != mCurrentColor)
		{
			mCurrentColor = color;
			
			var g = cast(mContext, Sprite).graphics;
			g.clear();
			
			var alpha = color >>> 24;
			if (alpha > 0)
			{
				g.beginFill(color & 0xFFFFFF, alpha / 0xFF);
				
				var r = target.internalResolution;
				if (r != null)
					g.drawRect(0, 0, r.x, r.y);
				else
				{
					var viewport = target.getPixelViewport();
					g.drawRect(0, 0, viewport.w, viewport.h);
				}
				g.endFill();
			}
		}
		
		mCleared = true;
	}
	
	override function onBeginScene()
	{
		super.onBeginScene();
		
		if (mCleared)
		{
			//run only once between clear() and present() as multiple
			//calls to drawScene() are possible
			mCleared = false;
			
			mZIndex = 0;
			var n = mBitmapList.head;
			while (n != null)
			{
				n.val.rendered = false;
				n = n.next;
			}
		}
	}
	
	override function onEndScene()
	{
		var n = mBitmapList.head;
		while (n != null)
		{
			var next = n.next;
			
			var o = n.val;
			if (!o.rendered)
				o.visible = false;
			
			//remove idle bitmaps that haven't been redrawn for more than one second.
			o.idleTime += Timebase.timeDelta;
			if (o.hasParent && o.idleTime > 1)
			{
				var success = mBitmapLookup.clr(o.spatial.key);
				assert(success);
				o.reset();
				mPool.push(o);
			}
			
			n = next;
		}
		
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
		var bmp = getBitmap(currentVisual); //getShape() for visual
		bmp.rendered = true;
		bmp.idleTime = 0;
		
		var shape = mScratchShape;
		if (shape == null) shape = mScratchShape = new Shape();
		var g = shape.graphics;
		
		var w = currentVisual.world;
		var s = w.getScale();
		
		g.beginFill(effect.color, 1);
		g.drawRect(0, 0, s.y, s.y);
		g.endFill();
		
		shape.transform.matrix = transformationToMatrix(currentVisual.world, s.x, s.y, mTmpMatrix);
		
		/*var visible = bmp.visible;
		var frameChanged = bmp.key != bmd.key;
		
		if (!visible) bmp.visible = true;
		
		if (frameChanged) bmp.draw(bmd);
		
		if (frameChanged || (currentVisual.mFlags & Spatial.GS_UPDATED) > 0 || !visible)
		{
			var uv = effect.cropRectPx;
			bmp.transform.matrix = transformationToMatrix(currentVisual.world, s.x, s.y, mTmpMatrix);
		}*/
		
		addBitmap(bmp, effect);
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		var bmp = getBitmap(currentVisual);
		var bmd = getBitmapData(effect.getFrameIndex() << 16 | effect.texture.key, effect.texture, effect);
		
		var visible = bmp.visible;
		var frameChanged = bmp.key != bmd.key;
		if (frameChanged) bmp.draw(bmd);
		if (frameChanged || (currentVisual.mFlags & Spatial.GS_UPDATED) > 0 || !visible)
		{
			var uv = effect.cropRectPx;
			bmp.transform.matrix = transformationToMatrix(currentVisual.world, uv.w, uv.h, mTmpMatrix);
		}
		
		addBitmap(bmp, effect);
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
		//TODO alpha blending
		var world = currentVisual.world;
		
		var canvas = mTileMapCanvas; //TODO getBmd for tilemap - multiple layers!
		if (canvas == null || effect.sizeChanged)
		{
			var size = getCamera().getSize();
			
			if (canvas != null) canvas.dispose();
			
			var w = effect.numVisTilesX * effect.tileSize;
			var h = effect.numVisTilesY * effect.tileSize;
			canvas = mTileMapCanvas = new BitmapData(w, h, true, 0);
		}
		
		if (effect.redraw)
		{
			var data = effect.texture.imageData;
			
			var t = effect.screenTiles;
			var p = mTmpPoint;
			var r = mTmpRect;
			var s = effect.tileSize;
			var atlas = effect.atlas;
			
			canvas.lock();
			for (y in 0...t.getH())
			{
				for (x in 0...t.getW())
				{
					var gid = t.get(x, y);
					if (gid <= 0)
					{
						r.x = x * s;
						r.y = y * s;
						r.width = s;
						r.height = s;
						canvas.fillRect(r, 0);
						continue;
					}
					else
					{
						var uv = atlas.getFrameAt(gid).texCoordPx;
						r.x = uv.x;
						r.y = uv.y;
						r.width = uv.w;
						r.height = uv.h;
						p.x = x * s;
						p.y = y * s;
						canvas.copyPixels(data, r, p);
					}
				}
			}
			canvas.unlock();
		}
		
		//var key = 0xffff;
		//var o = new SpatialBitmapData(key, canvas, canvas.rect.clone());
		//mBitmapDataLookup.set(key, o);
		
		var bmp = getBitmap(currentVisual);
		bmp.bitmapData = canvas;
		bmp.transform.matrix = transformationToMatrix(currentVisual.world, 1, 1, mTmpMatrix);
		
		addBitmap(bmp, effect);
	}
	
	function addBitmap(bmp:SpatialBitmap, effect:Effect)
	{
		bmp.rendered = true;
		bmp.idleTime = 0;
		
		var visible = bmp.visible;
		if (!visible) bmp.visible = true;
		
		if (!bmp.hasParent)
		{
			bmp.hasParent = true;
			mContext.addChild(bmp);
		}
		
		if (bmp.oldAlpha != currentAlphaMultiplier)
		{
			bmp.oldAlpha = currentAlphaMultiplier;
			bmp.alpha = currentAlphaMultiplier;
		}
		
		if (mCurrentBlendMode != bmp.prevBlendMode)
		{
			bmp.prevBlendMode = mCurrentBlendMode;
			bmp.blendMode = mCurrentBlendMode;
		}
		
		mContext.setChildIndex(bmp, mZIndex++);
		
		//TODO replace with state
		//if (effect.flags & Effect.EFFECT_COLOR_XFORM > 0)
			//bmp.transform.colorTransform = getColorTransform(effect);
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
		var sx = smooth ? (s.x / w) * 1.001 : (s.x / w); //hack: required to draw smooth bitmaps
		var sy = smooth ? (s.y / h) * 1.001 : (s.y / h);
		
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
			var m = mModel;
			m.m11 = sx * r.m11;
			m.m21 = sx * r.m21;
			m.m12 = sy * r.m12;
			m.m22 = sy * r.m22;
			m.tx = t.x;
			m.ty = t.y;
			
			//TODO use optimized version
			Mat44.matrixProduct(currentViewProjMat, m, mvp);
			
			out.a = mvp.m11;
			out.b = mvp.m21;
			out.c = mvp.m12;
			out.d = mvp.m22;
			out.tx = mvp.tx;
			out.ty = mvp.ty;
		}
		
		return out;
	}
	
	inline function getColorTransform(effect:Effect):NativeColorTransform
	{
		var output = null;
		//if (bits & EFFECT_ALPHA > 0)
		//{
			//output = mTmpColorTransformAlpha;
			//output.alphaMultiplier = currentAlphaMultiplier;
			
			//if (bits & EFFECT_COLOR_XFORM > 0)
				//output.concat(toFlashColorTransform(effect));
		//}
		//else
		//if (bits & EFFECT_COLOR_XFORM > 0)
			//output = toFlashColorTransform(effect);
		
		return output;
	}
	
	inline function toFlashColorTransform(value:ColorTransform, output:NativeColorTransform):NativeColorTransform
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
	
	inline function getBitmap(spatial:Spatial):SpatialBitmap
	{
		var bmp = mBitmapLookup.get(spatial.key);
		if (bmp == null)
			return initDisplayListObject(spatial);
		else
			return bmp;
	}
	
	inline function getBitmapData(key:Int, tex:Texture, effect:Effect):SpatialBitmapData
	{
		assert(key != -1);
		
		var transparent = mCurrentBlendMode != null;
		if (transparent) key |= (1 << 31);
		
		var o = mBitmapDataLookup.get(key);
		if (o == null)
			return initBitmapDataObject(key, tex, cast effect, transparent);
		else
			return o;
	}
	
	function initDisplayListObject(spatial:Spatial):SpatialBitmap
	{
		#if debug
		for (i in mBitmapList)
			if (i.spatial == spatial)
				assert(false);
		#end
		
		var o:SpatialBitmap =
		if (mPool.length > 0)
			mPool.pop();
		else
			new SpatialBitmap();
		
		o.listNode = mBitmapList.append(o);
		o.spatial = spatial;
		mBitmapLookup.set(spatial.key, o);
		
		mContext.addChild(o);
		o.hasParent = true;
		
		return o;
	}
	
	function initBitmapDataObject(key:Int, tex:Texture, effect:TextureEffect, transparent:Bool):SpatialBitmapData
	{
		var uv = effect.cropRectPx;
		mTmpRect.x = uv.x;
		mTmpRect.y = uv.y;
		mTmpRect.width = uv.w;
		mTmpRect.height = uv.h;
		
		mTmpPoint.x = 0;
		mTmpPoint.y = 0;
		
		var bitmapData = new BitmapData(cast uv.w, cast uv.h, transparent, 0);
		bitmapData.copyPixels(tex.imageData, mTmpRect, mTmpPoint);
		
		var o = new SpatialBitmapData(key, bitmapData, bitmapData.rect.clone());
		mBitmapDataLookup.set(key, o);
		
		return o;
	}
}

@:publicFields
private class SpatialBitmap extends Bitmap
{
	var spatial:Spatial;
	var key:Int;
	var listNode:DllNode<SpatialBitmap>;
	var hasParent:Bool;
	var rendered:Bool;
	var idleTime:Float;
	var oldAlpha:Float;
	var prevBlendMode:BlendMode;
	
	function new()
	{
		super(null, PixelSnapping.NEVER, true);
		key = -1;
	}
	
	inline function draw(x:SpatialBitmapData)
	{
		key = x.key;
		bitmapData = x.bitmapData;
		smoothing = true;
	}
	
	inline function reset()
	{
		transform.matrix = null;
		hasParent = false;
		key = -1;
		DisplayListUtil.remove(this);
		
		listNode.unlink();
		listNode.free();
		listNode = null;
	}
	
	function free()
	{
		bitmapData.dispose();
		DisplayListUtil.remove(this);
		spatial = null;
		listNode.unlink();
		listNode.free();
		listNode = null;
	}
}

@:publicFields
private class SpatialBitmapData
{
	var key:Int;
	var bitmapData:BitmapData;
	var rect:Rectangle;
	
	function new(key:Int, bitmapData:BitmapData, rect:Rectangle)
	{
		this.key = key;
		this.bitmapData = bitmapData;
		this.rect = rect;
	}
	
	function free()
	{
		bitmapData.dispose();
		bitmapData = null;
		rect = null;
	}
}