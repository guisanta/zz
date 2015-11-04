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
import de.polygonal.core.math.Rect.Recti;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.Graphics;
import flash.display.TriangleCulling;
import flash.geom.ColorTransform;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.Lib;
import haxe.ds.Vector;

private typedef NativeVector<T> = flash.Vector<T>;

/**
	A renderer that uses the `flash.display.Graphics` API.
**/
class GraphicsRenderer extends Renderer
{
	var mContext:Graphics;
	
	var mQuadVertices:NativeVector<Float>;
	var mQuadIndices:NativeVector<Int>;
	var mQuadUvt:NativeVector<Float>;
	
	var mTmpRect:Rectangle;
	var mTmpPoint:Point;
	var mTmpColorTransform:ColorTransform;
	var mScratchBitmap:BitmapData;
	
	var mViewport:Recti;
	
	var mCurrBlendMode:BlendMode;
	
	public function new()
	{
		super();
		
		supportsNonPowerOfTwoTextures = true;
		
		mQuadVertices = new NativeVector<Float>(4 * 2);
		mQuadIndices = Vector.fromArrayCopy([0, 1, 2, 0, 2, 3]).toData();
		mQuadUvt = new NativeVector<Float>(4 * 2);
		
		mTmpRect = new Rectangle();
		mTmpPoint = new Point();
		mTmpColorTransform = new ColorTransform();
		
		mCurrBlendMode = BlendMode.NORMAL;
	}
	
	override public function free()
	{
		super.free();
		
		if (mScratchBitmap != null) mScratchBitmap.dispose();
		mScratchBitmap = null;
	}
	
	override function onInitRenderContext(handle:Dynamic)
	{
		assert(Std.is(handle, Graphics), "invalid context: flash.display.Graphics required");
		
		mContext = Lib.as(handle, Graphics);
	}
	
	override function clear()
	{
		var target = getRenderTarget();
		if (target == null || mContext == null) return;
		
		mContext.clear();
		
		mContext.beginFill(target.color, 1);
		var v = target.getPixelViewport();
		mContext.drawRect(0, 0,v.w, v.h);
		mContext.endFill();
		
		mViewport = target.getPixelViewport();
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		//TODO color transformation, alpha, blendMode
		
		setModelViewProjMatrix(currentVisual);
		mContext.beginFill(effect.color, currentAlphaMultiplier);
		mContext.drawTriangles(getScreenQuad(), mQuadIndices, TriangleCulling.NONE);
		mContext.endFill();
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		//TODO color transformation, alpha, blendMode
		
		setModelViewProjMatrix(currentVisual);
		
		var uvt = mQuadUvt;
		var bmd = effect.texture.imageData;
		
		if (currentAlphaMultiplier == 1 && mCurrBlendMode == BlendMode.NORMAL)
		{
			var c = effect.cropRectUv;
			var x = c.x;
			var y = c.y;
			var w = c.w;
			var h = c.h;
			
			uvt[0] = x;
			uvt[1] = y;
			uvt[2] = x + w;
			uvt[3] = y;
			uvt[4] = x + w;
			uvt[5] = y + h;
			uvt[6] = x;
			uvt[7] = y + h;
		}
		else
		{
			//TODO first render to texture
			var c = effect.cropRectPx;
			
			assert(c.w <= 1024 && c.h <= 1024);
			
			var a = c.w / 1024;
			var b = c.h / 1024;

			uvt[0] = 0;
			uvt[1] = 0;
			uvt[2] = a;
			uvt[3] = 0;
			uvt[4] = a;
			uvt[5] = b;
			uvt[6] = 0;
			uvt[7] = b;
			
			var r = mTmpRect;
			r.x = c.x;
			r.y = c.y;
			r.width = c.w;
			r.height = c.h;
			
			var scratch = mScratchBitmap;
			if (scratch == null) scratch = mScratchBitmap = new BitmapData(1024, 1024, true, 0);
			
			//TODO blend mode
			
			mTmpColorTransform.alphaMultiplier = currentAlphaMultiplier; 
			
			if (mCurrBlendMode == null)
			{
				scratch.copyPixels(bmd, r, mTmpPoint, false);
				scratch.colorTransform(r, mTmpColorTransform);
			}
			else
			{
				if (mCurrBlendMode == BlendMode.NORMAL)
				{
					scratch.copyPixels(bmd, r, mTmpPoint, true);
					scratch.colorTransform(r, mTmpColorTransform);
				}
				else
				{
					scratch.draw(bmd, mTmpColorTransform, mCurrBlendMode, r, false);
				}
			}
			
			bmd = scratch;
		}
		
		var ctx = mContext;
		ctx.beginBitmapFill(bmd, null, false, smooth);
		ctx.drawTriangles(getScreenQuad(), mQuadIndices, uvt, TriangleCulling.NONE);
		ctx.endFill();
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
		var w = effect.numVisTilesX;
		var h = effect.numVisTilesY;
		
		setModelViewProjMatrix(currentVisual);
		
		//TODO preallocate indices/vertices
		var indices = [];
		var vertices = [];
		
		var uvt:Array<Float> = [];
		
		var s = effect.tileSize;
		
		var v = mScratchVec;
		
		var c = 0;
		var i = 0;
		for (y in 0...h)
		{
			for (x in 0...w)
			{
				var gid = effect.screenTiles.get(x, y);
				if (gid > 0)
				{
					v.x = x * s;
					v.y = y * s;
					clipToScreenSpace(currentMvp.timesVector(v), v);
					vertices[i++] = v.x;
					vertices[i++] = v.y;
					
					v.x = (x + 1) * s;
					v.y = y * s;
					clipToScreenSpace(currentMvp.timesVector(v), v);
					vertices[i++] = v.x;
					vertices[i++] = v.y;
					
					v.x = (x + 1) * s;
					v.y = (y + 1) * s;
					clipToScreenSpace(currentMvp.timesVector(v), v);
					vertices[i++] = v.x;
					vertices[i++] = v.y;
					
					v.x = x * s;
					v.y = (y + 1) * s;
					clipToScreenSpace(currentMvp.timesVector(v), v);
					vertices[i++] = v.x;
					vertices[i++] = v.y;
					
					indices.push(c);
					indices.push(c + 1);
					indices.push(c + 2);
					indices.push(c);
					indices.push(c + 2);
					indices.push(c + 3);
					
					c += 4;
					
					var frame = effect.atlas.getFrameAt(gid);
					var uv = frame.texCoordUv;
					uvt.push(uv.x);
					uvt.push(uv.y);
					uvt.push(uv.x + uv.w);
					uvt.push(uv.y);
					uvt.push(uv.x + uv.w);
					uvt.push(uv.y + uv.h);
					uvt.push(uv.x);
					uvt.push(uv.y + uv.h);
				}
				else
				{
					for (j in 0...8)
					{
						vertices[i++] = 0;
						uvt.push(0);
					}
					for (j in 0...6) indices.push(c);
					c += 4;
				}
			}
		}
		
		//TODO draw into bitmap.
		//create quad and transform quad, then draw into quad.
		//TODO alpha blending
		
		var vert = Vector.fromArrayCopy(vertices).toData();
		var ind = Vector.fromArrayCopy(indices).toData();
		var uvtt = Vector.fromArrayCopy(uvt).toData();
		
		
		
		
		
		
		
		
		
		
		
		var ctx = mContext;
		ctx.beginBitmapFill(effect.texture.imageData, null, true, smooth);
		ctx.drawTriangles(vert, ind, uvtt, TriangleCulling.NONE);
		ctx.endFill();
	}
	
	override function getProjectionMatrix():Mat44
	{
		mProjMatrix.setAsIdentity();
		
		//default projection space is from [-1,1]
		var c = getCamera();
		
		if (c != null)
		{
			//projection components
			mProjMatrix.m11 = 2 / c.sizeX;
			mProjMatrix.m22 = 2 / c.sizeY;
		}
		else
		{
			mProjMatrix.tx = -1;
			mProjMatrix.ty = 1;
			
			//projection components
			var s = getRenderTarget().getSize();
			mProjMatrix.m11 = 2 / s.x;
			mProjMatrix.m22 = 2 / s.y;
		}
		
		//flip y-axis
		mProjMatrix.m22 *= -1; 
		
		return mProjMatrix;
	}
	
	override public function setAlphaBlendState(value:AlphaBlendMode)
	{
		mCurrBlendMode =
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
	
	inline function clipToScreenSpace(input:Vec3, output:Vec3)
	{
		var v = mViewport;
		
		output.x = (input.x + 1) * (v.w * .5) + 0;
		output.y = (1 - input.y) * (v.h * .5) + 0; //flip y
		
		//output.x = (input.x + 1) * (v.w * .5) + v.x;
		//output.y = (1 - input.y) * (v.h * .5) + v.y; //flip y
	}
	
	function getScreenQuad():NativeVector<Float>
	{
		var v = mScratchVec;
		var vertices = mQuadVertices;
		
		v.x = 0;
		v.y = 0;
		clipToScreenSpace(currentMvp.timesVector(v), v);
		vertices[0] = v.x;
		vertices[1] = v.y;
		
		v.x = 1;
		v.y = 0;
		clipToScreenSpace(currentMvp.timesVector(v), v);
		vertices[2] = v.x;
		vertices[3] = v.y;
		
		v.x = 1;
		v.y = 1;
		clipToScreenSpace(currentMvp.timesVector(v), v);
		vertices[4] = v.x;
		vertices[5] = v.y;
		
		v.x = 0;
		v.y = 1;
		clipToScreenSpace(currentMvp.timesVector(v), v);
		vertices[6] = v.x;
		vertices[7] = v.y;
		
		return vertices;
	}
}