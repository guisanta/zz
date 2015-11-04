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
package de.polygonal.zz.render.platform.js;

import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.math.Vec3;
import de.polygonal.zz.data.Color;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import de.polygonal.zz.scene.Xform;
import haxe.ds.IntMap;
import haxe.ds.Vector;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;

/**
	A HTML5 Canvas renderer.
**/
class Canvas2dRenderer extends Renderer
{
	public var context(default, null):CanvasRenderingContext2D;
	
	var mLastBlending:String;
	var mCurrentBlending:String;
	var mLastAlpha:Float; //TODO use callback function
	var mModel:Mat44;
	var mTileMapCanvasLut:IntMap<{element:CanvasElement, context:CanvasRenderingContext2D}>;
	var mSmoothingFlag:String;
	var mColorChannels = new Vector<Int>(4);
	var mAllowBlitting = false;
	
	public function new()
	{
		super();
		
		mLastBlending = null;
		mCurrentBlending = "source-over";
		
		mLastAlpha =-1;
		currentAlphaMultiplier = 1;
		
		supportsNonPowerOfTwoTextures = true;
		
		mModel = new Mat44();
		
		var ua = Browser.navigator.userAgent;
		mSmoothingFlag =
		if (ua.toLowerCase().indexOf('firefox') > -1) "mozImageSmoothingEnabled";
		else
		if (ua.indexOf("MSIE ") > 0 || ua.indexOf("Trident/7.0") > 0) "msImageSmoothingEnabled";
		else "imageSmoothingEnabled";
	}
	
	override public function free()
	{
		context = null;
		super.free();
	}
	
	override function onInitRenderContext(handle:Dynamic)
	{
		context = cast handle;
	}
	
	override function clear() 
	{
		var target = getRenderTarget();
		var viewport = target.getPixelViewport();
		
		var w = viewport.w;
		var h = viewport.h;
		
		if (target.internalResolution != null)
		{
			w = target.internalResolution.x;
			h = target.internalResolution.y;
		}
		
		Color.extractR8G8B8(target.color, mColorChannels);
		var r = mColorChannels[0];
		var g = mColorChannels[1];
		var b = mColorChannels[2];
		context.fillStyle = 'rgb($r,$g,$b)';
		context.globalCompositeOperation = "copy";
		context.fillRect(0, 0, w, h);
		context.globalCompositeOperation = "source-over";
	}
	
	override function onBeginScene()
	{
		super.onBeginScene();
		
		var c = getCamera();
		if (c == null)
			mAllowBlitting = true;
		else
		{
			//TODO with viewport?
			//var targetSize = getRenderTarget().getSize();
			//var vp = getRenderTarget().getPixelViewport();
			//trace( "targetSize : " + vp.w + ' ' + vp.h + ' ' + c.sizeX + ' ' + c.sizeY);
			//mAllowBlitting = targetSize.x == c.sizeX && targetSize.y == c.sizeY && c.rotation == 0;
		}
		
		mAllowBlitting = true;
		
		context.save();
	}
	
	override function onEndScene()
	{
		context.restore();
		
		super.onEndScene();
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		var w = currentVisual.world;
		var s = w.getScale();
		var r = w.getRotate();
		var t = w.getTranslate();
		
		var ctx = context;
		setSmoothing(ctx, mSmooth);
		setGlobalCompositeOperation(ctx);
		setGlobalAlpha(ctx);
		ctx.setTransform(r.m11, r.m21, r.m12, r.m22, t.x, t.y);
		
		var color = effect.color;
		var rgb = mColorChannels;
		
		Color.extractR8G8B8(color, rgb);
		ctx.fillStyle = 'rgba(${rgb[0]},${rgb[1]},${rgb[2]},1)';
		ctx.fillRect(0, 0, s.x, s.y);
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		//http://www.w3.org/TR/2dcontext/#drawing-images-to-the-canvas
		var ctx = context;
		setSmoothing(ctx, mSmooth);
		setGlobalCompositeOperation(ctx);
		setGlobalAlpha(ctx);
		
		var data:Dynamic = effect.texture.imageData;
		var cr = effect.cropRectPx;
		var w = currentVisual.world;
		var s = w.getScale();
		var t = w.getTranslate();
		
		var flip = s.x < 0 || s.y < 0;
		
		mAllowBlitting = false;
		
		if (!mAllowBlitting || !w.isIdentityRotation() || flip)
		{
			setTransform(w, ctx);
			
			if (flip) //flip image h/v
			{
				ctx.save();
				ctx.scale(s.x < 0 ? -1 : 1, s.y < 0 ? -1 : 1);
				ctx.drawImage(data, cr.x, cr.y, cr.w, cr.h, 0, 0, M.fabs(s.x), M.fabs(s.y));
				ctx.restore();
			}
			else
				ctx.drawImage(data, cr.x, cr.y, cr.w, cr.h, 0, 0, s.x, s.y);
		}
		else
			ctx.drawImage(data, cr.x, cr.y, cr.w, cr.h, t.x, t.y, s.x, s.y);
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
		if (mTileMapCanvasLut == null)
			mTileMapCanvasLut = new IntMap();
		
		var o = mTileMapCanvasLut.get(effect.key);
		if (o == null)
		{
			var canvas = Browser.document.createCanvasElement();
			var context = canvas.getContext2d();
			o = {element: canvas, context: context};
			mTileMapCanvasLut.set(effect.key, o);
		}
			
		if (effect.sizeChanged)
		{
			o.element.width = effect.numVisTilesX * effect.tileSize;
			o.element.height = effect.numVisTilesY * effect.tileSize;
		}
		
		if (effect.redraw)
		{
			var data:Dynamic = effect.texture.imageData;
			var t = effect.screenTiles;
			var s = effect.tileSize;
			var atlas = effect.atlas;
			
			var ctx = o.context;
			var gid, uv, dx, dy;
			
			ctx.clearRect(0, 0, o.element.width, o.element.height);
			setSmoothing(ctx, false);
			
			for (y in 0...t.getH())
			{
				for (x in 0...t.getW())
				{
					gid = t.get(x, y);
					dx = x * s;
					dy = y * s;
					if (gid > 0)
					{
						uv = atlas.getFrameAt(gid).texCoordPx;
						ctx.drawImage(data, uv.x, uv.y, uv.w, uv.h, dx, dy, s, s);
					}
					else
						ctx.drawImage(data, 0, 0, s, s, dx, dy, s, s);
				}
			}
		}
		
		var ctx = context;
		setSmoothing(ctx, mSmooth);
		setGlobalCompositeOperation(ctx);
		setGlobalAlpha(ctx);
		setTransform(currentVisual.world, ctx);
		
		ctx.drawImage(o.element, 0, 0);
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
	
	override public function setAlphaBlendState(value:AlphaBlendMode)
	{
		mCurrentBlending =
		switch (value)
		{
			case AlphaBlendMode.Normal: "source-over";
			case AlphaBlendMode.Add: "lighter";
			case AlphaBlendMode.Screen: "screen";
			case AlphaBlendMode.Multiply: "multiply";
			case AlphaBlendMode.None: "none";
			case AlphaBlendMode.User(_, _): throw "unsupported blend mode";
		}
	}
	
	inline function setGlobalCompositeOperation(context:CanvasRenderingContext2D)
	{
		if (mCurrentBlending != mLastBlending)
		{
			mLastBlending = mCurrentBlending;
			context.globalCompositeOperation = mCurrentBlending;
		}
	}
	
	inline function setGlobalAlpha(context:CanvasRenderingContext2D)
	{
		if (currentAlphaMultiplier != mLastAlpha)
		{
			mLastAlpha = currentAlphaMultiplier;
			context.globalAlpha = currentAlphaMultiplier;
		}
	}
	
	inline function setSmoothing(context:CanvasRenderingContext2D, value:Bool)
	{
		if (untyped context[mSmoothingFlag] != value)
			untyped context[mSmoothingFlag] = value;
	}
	
	inline function setTransform(xf:Xform, context:CanvasRenderingContext2D)
	{
		var r = xf.getRotate();
		var t = xf.getTranslate();
		
		if (getCamera() == null)
			context.setTransform(r.m11, r.m21, r.m12, r.m22, t.x, t.y);
		else
		{
			var mvp = currentMvp;
			var m = mModel;
			
			m.m11 = r.m11;
			m.m21 = r.m21;
			m.m12 = r.m12;
			m.m22 = r.m22;
			m.tx = t.x;
			m.ty = t.y;
			
			Mat44.affineMatrixProduct2d(currentViewProjMat, m, mvp);
			
			context.setTransform(mvp.m11, mvp.m21, mvp.m12, mvp.m22, mvp.tx, mvp.ty);
		}
	}
}