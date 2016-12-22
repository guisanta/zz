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
package de.polygonal.zz.render.platform.flash.stage3d;

import de.polygonal.core.math.Mat44;
import de.polygonal.ds.tools.Bits;
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.IntHashTable;
import de.polygonal.zz.data.Color;
import de.polygonal.zz.data.Colori;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.platform.flash.stage3d.*;
import de.polygonal.zz.render.platform.flash.stage3d.painter.*;
import de.polygonal.zz.render.platform.flash.stage3d.painter.Painter;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import de.polygonal.zz.scene.GlobalStateType;
import de.polygonal.zz.texture.Texture;
import flash.display.BitmapData;
import flash.display3D.*;
import flash.geom.Matrix;
import haxe.EnumFlags;

import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import flash.display3D.textures.Texture as Stage3dTexture;

@:enum
abstract BatchStrategy(Int)
{
	var None = 0;
	var VertexBufferBatch = 1;
	var ConstantRegisterBatch = 2;
}

@:access(de.polygonal.zz.scene.Spatial)
class Stage3dRenderer extends Renderer
{
	public var numCallsToDrawTriangle(default, null):Int;
	public var favorBatchSizeOverShaderSize:Bool = false;
	public var handleContextLoss:Bool = true;
	public var batchStrategy(default, null):BatchStrategy;
	
	var mContext:Context3D;
	
	var mPainterLut:IntHashTable<Painter>;
	var mTextureLut:IntHashTable<Stage3dTexture>;
	var mSrcBlendFactorLut:Array<Context3DBlendFactor>;
	var mDstBlendFactorLut:Array<Context3DBlendFactor>;
	var mSrcFactor:Context3DBlendFactor = null;
	var mDstFactor:Context3DBlendFactor = null;
	var mColorChannels = new Colori();
	
	var mRenderState1 = new RenderState();
	var mRenderState2 = new RenderState();
	var mBatchIntervals = new ArrayList<Int>();
	
	var mTextureFlags:Int;
	var mCurrentPainter:Painter;
	
	var mTileMapPainterLut:IntHashTable<PainterTileMap>;
	
	var mContextLost:Bool;
	
	public function new(textureFlags:Int, batchStrategy:BatchStrategy)
	{
		super();
		
		this.batchStrategy = batchStrategy;
		
		L.d('texture bits: ${Stage3dTextureFlag.print(textureFlags)}', "s3d");
		mTextureFlags = textureFlags;
		
		mSrcBlendFactorLut =
		[
			ZERO,
			ONE,
			DESTINATION_COLOR,
			ONE_MINUS_DESTINATION_COLOR,
			SOURCE_ALPHA,
			ONE_MINUS_SOURCE_ALPHA,
			DESTINATION_ALPHA,
			ONE_MINUS_DESTINATION_ALPHA
		];
		mDstBlendFactorLut =
		[
			ZERO,
			ONE,
			SOURCE_COLOR,
			ONE_MINUS_SOURCE_COLOR,
			SOURCE_ALPHA,
			ONE_MINUS_SOURCE_ALPHA,
			DESTINATION_ALPHA,
			ONE_MINUS_DESTINATION_ALPHA
		];
		
		mTextureLut = new IntHashTable<Stage3dTexture>(32, 32);
		mPainterLut = new IntHashTable<Painter>(256, 256);
	}
	
	override public function free()
	{
		for (handle in mTextureLut)
		{
			if (handle == null) continue;
			
			try
			{
				handle.dispose();
			}
			catch (error:Dynamic)
			{
				L.e('failed disposing texture object: $error', "s3d");
			}
		}
		mTextureLut.free();
		mTextureLut = null;
		
		super.free();
	}
	
	override function onInitRenderContext(handle:Dynamic)
	{
		assert(Std.is(handle, Context3D), "invalid context: flash.display3D.Context3D required");
		
		mContextLost = false;
		mContext = cast(handle, Context3D);
		
		setAlphaBlendState(AlphaBlendMode.Normal);
	}
	
	override function onRestoreRenderContext(handle:Dynamic)
	{
		mContext = cast(handle, Context3D);
		mContextLost = true;
	}
	
	override public function drawScene(scene:Node)
	{
		if (mContextLost)
		{
			mContextLost = false;
			
			L.w("recovering from context lost ...", "s3d");
			
			for (i in mPainterLut) i.free();
			mPainterLut.clear();
			
			for (i in mTextureLut) i.dispose();
			mTextureLut.clear();
			
			if (currentAlphaBlending != null)
				setAlphaBlendState(currentAlphaBlending.alphaBlendMode);
			else
			{
				mSrcFactor = null;
				mDstFactor = null;
				setAlphaBlendState(AlphaBlendMode.Normal);
			}
		}
		
		super.drawScene(scene);
	}
	
	override function clear()
	{
		var target = getRenderTarget();
		if (target == null) return;
		
		Color.extractR8G8B8(target.color, mColorChannels);
		var r = mColorChannels.r / 0xFF;
		var g = mColorChannels.g / 0xFF;
		var b = mColorChannels.b / 0xFF;
		
		if (mContext != null) mContext.clear(r, g, b, 1);
		
		numCallsToDrawTriangle = 0;
	}
	
	override function present()
	{
		if (mContext != null) mContext.present();
		
		super.present();
	}
	
	inline public function getTextureObject(source:Texture):Stage3dTexture
	{
		return mTextureLut.get(source.key);
	}
	
	public function createAndUploadTextureObject(source:Texture):Stage3dTexture
	{
		var o = mContext.createTexture(source.paddedSize.x, source.paddedSize.y, source.format, false, 0);
		mTextureLut.set(source.key, o);
		
		if (source.isCompressed)
			o.uploadCompressedTextureFromByteArray(source.atfData, 0);
		else
		{
			if (mTextureFlags & (Stage3dTextureFlag.MM_LINEAR | Stage3dTextureFlag.MM_NEAREST) > 0) //mipmaps?
			{
				var w = source.paddedSize.x;
				var h = source.paddedSize.y;
				
				var level = 0;
				var scratch = new BitmapData(w, h, true, 0);
				var transform = new Matrix();
				while (w >= 1 || h >= 1)
				{
					scratch.fillRect(scratch.rect, 0);
					scratch.draw(source.imageData, transform, null, null, null, true);
					o.uploadFromBitmapData(scratch, level);
					transform.scale(.5, .5);
					level++;
					w >>= 1;
					h >>= 1;
				}
				scratch.dispose();
			}
			else
				o.uploadFromBitmapData(source.imageData, 0);
		}
		
		if (!handleContextLoss)
		{
			if (source.imageData != null)
			{
				source.imageData.dispose();
				source.imageData = null;
			}
		}
		
		return o;
	}
	
	/**
		Frees all gpu resources associated with the given texture object.
	**/
	public function disposeTextureObject(source:Texture)
	{
		var o = mTextureLut.get(source.key);
		if (o != null)
		{
			L.d('disposing texture object [${source.key}]', "s3d");
			
			try
			{
				o.dispose();
			}
			catch (error:Dynamic)
			{
				L.w('failed disposing object [${source.key}]', "s3d");
			}
			
			mTextureLut.unset(source.key);
		}
	}
	
	override public function drawVisibleSet(visibleSet:ArrayList<Visual>)
	{
		mCurrentPainter = null;
		
		if (visibleSet.isEmpty()) return;
		
		#if (verbose == "extra")
		L.v('Drawing visible set: count=${visibleSet.size}, strategy=$batchStrategy', "s3d");
		#end
		
		if (batchStrategy == None)
		{
			super.drawVisibleSet(visibleSet);
			return;
		}
		
		/** find batch groups by comparing render states  **/
		
		var indices = mBatchIntervals;
		indices.clear();
		
		var state1 = mRenderState1, state2 = mRenderState2, tmp;
		
		if (favorBatchSizeOverShaderSize)
		{
			//mask out (ignore) alpha multiplier state since those values change often
			var mask = (1 << AlphaBlend.getIndex()) | (1 << ColorTransform.getIndex());
			state1.stateMask = mask;
			state2.stateMask = mask;
		}
		else
		{
			//minimize shader complexity
			state1.stateMask = 0xFF;
			state2.stateMask = 0xFF;
		}
		
		var itr:ArrayListIterator<Visual> = cast visibleSet.iterator();
		
		var a = itr.next(), b;
		
		//find first visual pointing to a valid effect instance
		while (a.effect == null && itr.hasNext()) a = itr.next();
		
		//quit: none of the visuals have a valid effect assigned
		if (a.effect == null) return;
		
		var min = 0;
		var max = 0;
		
		state1.set(a);
		
		while (itr.hasNext())
		{
			b = itr.next();
			
			if (b.effect == null) continue;
			
			state2.set(b);
			
			if (state1.equals(state2))
			{
				//accumulate
				a = b;
				max++;
			}
			else
			{
				//finalize
				indices.pushBack(min);
				indices.pushBack(max);
				
				//start new batch by adding b
				min = max + 1;
				max = min;
				
				a = b;
				tmp = state1; state1 = state2; state2 = tmp;
			}
		}
		
		//remainder
		indices.pushBack(min);
		indices.pushBack(max);
		
		/** draw batch groups **/
		
		var featureFlags, stateFlags, batching, texture;
		
		var i = 0, k = indices.size;
		while (i < k)
		{
			min = indices.get(i++);
			max = indices.get(i++);
			
			#if (verbose == "extra")
			L.v('Drawing batch group #${i >> 1}: [$min, $max]', "s3d");
			#end
			
			currentVisual = visibleSet.get(min);
			currentEffect = currentVisual.effect;
			
			assert(currentEffect != null);
			
			batching = min != max;
			stateFlags = currentVisual.stateFlags;
			
			if (favorBatchSizeOverShaderSize)
			{
				//don't miss alpha multiplier state (ignored before)
				var j = min;
				while (j <= max)
				{
					if (visibleSet.get(j).stateFlags.has(GlobalStateType.AlphaMultiplier))
					{
						stateFlags.set(GlobalStateType.AlphaMultiplier);
						break;
					}
					j++;
				}
			}
			
			//find a painter that supports the given features
			setPainter(currentVisual.effect, stateFlags, batching);
			setGlobalState(currentVisual);
			
			//optimization: alpha blending state is set once for the entire batch group
			allowedGlobalStates.unset(AlphaBlend);
			
			//draw batch, this invokes one or multiple calls to drawTriangles()
			if (batching)
				mCurrentPainter.draw(this, visibleSet, min, max);
			else
				mCurrentPainter.draw(this, currentVisual);
			
			//restore state
			allowedGlobalStates.set(AlphaBlend);
		}
	}
	
	override function setAlphaMultiplierState(value:Float)
	{
	}
	
	override function onEndScene()
	{
		super.onEndScene();
		
		if (mCurrentPainter != null) mCurrentPainter.unbind();
	}
	
	override public function setAlphaBlendState(value:AlphaBlendMode)
	{
		var srcFactor:Context3DBlendFactor = null;
		var dstFactor:Context3DBlendFactor = null;
		
		if (currentVisual == null || currentVisual.effect.pma)
		{
			switch (value)
			{
				case None:
					srcFactor = ONE;
					dstFactor = ZERO;
				
				case Normal:
					srcFactor = ONE;
					dstFactor = ONE_MINUS_SOURCE_ALPHA;
				
				case Multiply:
					srcFactor = DESTINATION_COLOR;
					dstFactor = ONE_MINUS_SOURCE_ALPHA;
				
				case Add:
					srcFactor = SOURCE_ALPHA;
					dstFactor = DESTINATION_ALPHA;
				
				case Screen:
					srcFactor = ONE;
					dstFactor = ONE_MINUS_SOURCE_COLOR;
				
				case User(src, dst):
					srcFactor = mSrcBlendFactorLut[src.getIndex()];
					dstFactor = mDstBlendFactorLut[dst.getIndex()];
			}
		}
		else
		{
			switch (value)
			{
				case None:
					srcFactor = ONE;
					dstFactor = ZERO;
				
				case Normal:
					srcFactor = SOURCE_ALPHA;
					dstFactor = ONE_MINUS_SOURCE_ALPHA;
				
				case Multiply:
					srcFactor = DESTINATION_COLOR;
					dstFactor = ONE_MINUS_SOURCE_ALPHA;
				
				case Add:
					srcFactor = ONE;
					dstFactor = ONE;
				
				case Screen:
					srcFactor = SOURCE_ALPHA;
					dstFactor = ONE;
				
				case User(src, dst):
					srcFactor = mSrcBlendFactorLut[src.getIndex()];
					dstFactor = mDstBlendFactorLut[dst.getIndex()];
			}
		}
		
		if (mSrcFactor != srcFactor || mDstFactor != dstFactor)
		{
			mContext.setBlendFactors(srcFactor, dstFactor);
			mSrcFactor = srcFactor;
			mDstFactor = dstFactor;
		}
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		setPainter(currentVisual.effect, currentVisual.stateFlags, batchStrategy != None);
		mCurrentPainter.draw(this, currentVisual);
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		setPainter(currentVisual.effect, currentVisual.stateFlags, batchStrategy != None);
		mCurrentPainter.draw(this, currentVisual);
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
		setPainter(currentVisual.effect, currentVisual.stateFlags, batchStrategy != None);
		
		mCurrentPainter.draw(this, currentVisual);
		
		return;
		
		//mNewStage3dTexture = 
		//if (getTextureObject(currentTexture) == null)
		//{
			//createAndUploadTextureObject(currentTexture);
		//}
		//else
			//null;
		
		/*if (mTileMapPainterLut == null)
			mTileMapPainterLut = new IntHashTable(64);
		
		var brush = mTileMapPainterLut.get(effect.key);		
		if (brush == null)
		{
			trace('create brush');
			brush = new PainterTileMap(this, mTextureFlags);
			mTileMapPainterLut.set(effect.key, brush);
		}*/
		
		//switchBrush(brush);
		//brush.draw(this);
		
		//mCurStage3dTexture = mNewStage3dTexture;
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
			
			//xw = (xnd + 1)(width / 2) + x
			//yw = (ynd + 1)(height / 2) + y
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
	
	inline function usePainter(painter:Painter)
	{
		assert(painter != null);
		
		if (mCurrentPainter == null)
		{
			mCurrentPainter = painter;
			painter.bind();
		}
		else
		if (mCurrentPainter != painter)
		{
			mCurrentPainter.unbind();
			mCurrentPainter = painter;
			painter.bind();
		}
		else
			mCurrentPainter = painter;
	}
	
	function setPainter(effect:Effect, globalStateFlags:EnumFlags<GlobalStateType>, batching:Bool)
	{
		//encode all features into a bitfield
		var key = 0;
		switch (effect.type)
		{
			case ColorEffect.TYPE:
				key |= PAINTER_FEATURE_COLOR;
			
			case TextureEffect.TYPE | TileMapEffect.TYPE:
				if (effect.pma)
					key |= PAINTER_FEATURE_TEXTURE_PMA;
				else
					key |= PAINTER_FEATURE_TEXTURE;
				
				if (effect.hint & TextureEffect.HINT_COMPRESSED > 0)
					key |= PAINTER_FEATURE_COMPRESSED;
				
				if (effect.hint & TextureEffect.HINT_COMPRESSED_ALPHA > 0)
					key |= PAINTER_FEATURE_COMPRESSED_ALPHA;
		}
		
		if (globalStateFlags.has(AlphaMultiplier)) key |= PAINTER_FEATURE_ALPHA;
		if (globalStateFlags.has(ColorTransform)) key |= PAINTER_FEATURE_COLOR_TRANSFORM;
		if (batching) key |= PAINTER_FEATURE_BATCHING;
		
		//lookup painter
		var painter = mPainterLut.get(key);
		if (painter != null)
		{
			usePainter(painter);
			return painter;
		}
		
		//create painter object on the fly
		var clss:Class<Painter> = null;
		var args:Array<Dynamic> = [this, key, 0];
		
		var textureFlags = mTextureFlags;
		
		if (effect.type == TileMapEffect.TYPE)
		{
			painter = new PainterTileMap(this, key, textureFlags);
			
			usePainter(painter);
			
			mPainterLut.set(key, painter);
		}
		
		if (key & PAINTER_FEATURE_COLOR > 0)
		{
			if (key & PAINTER_FEATURE_BATCHING > 0)
			{
				clss = PainterQuadColorBatch;
			}
			else
			{
				clss = PainterQuadColor;
			}
		}
		else
		if (key & (PAINTER_FEATURE_TEXTURE | PAINTER_FEATURE_TEXTURE_PMA) > 0)
		{
			if (key & PAINTER_FEATURE_BATCHING > 0)
			{
				clss = PainterQuadTextureBatch;
			}
			else
			{
				clss = PainterQuadTexture;
			}
			
			if (key & (PAINTER_FEATURE_COMPRESSED | PAINTER_FEATURE_COMPRESSED_ALPHA) > 0)
			{
				if (key & PAINTER_FEATURE_COMPRESSED > 0)
					textureFlags |= Stage3dTextureFlag.DXT1;
				
				if (key & PAINTER_FEATURE_COMPRESSED_ALPHA > 0)
					textureFlags |= Stage3dTextureFlag.DXT5;
			}
		}
		
		painter = Type.createInstance(clss, [this, key, textureFlags]);
		mPainterLut.set(key, painter);
		
		usePainter(painter);
		
		return painter;
	}
}

@:publicFields
private class RenderState
{
	var state:Int;
	var stateMask:Int = Bits.mask(GlobalStateType.getConstructors().length);
	var effect:Effect;
	var texture:Texture;
	
	function new() {}
	
	inline function set(visual:Visual)
	{
		state = visual.stateFlags.toInt();
		effect = visual.effect;
		texture = (effect.type == TextureEffect.TYPE) ? effect.as(TextureEffect).texture : null;
	}
	
	inline function equals(other:RenderState):Bool
	{
		if (state & stateMask != other.state & stateMask) return false;
		if (effect.type != other.effect.type) return false;
		if (texture != other.texture) return false;
		return true;
	}
}