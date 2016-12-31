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
package de.polygonal.zz.render.platform.nme;

import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Recti;
import de.polygonal.core.math.Vec3;
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.IntHashTable;
import de.polygonal.ds.IntIntHashTable;
import de.polygonal.ds.tools.Bits;
import de.polygonal.ds.tools.NativeArrayTools;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.Effect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.scene.AlphaBlendState.AlphaBlendMode;
import de.polygonal.zz.scene.GlobalStateType;
import de.polygonal.zz.scene.Visual;
import de.polygonal.zz.scene.Xform;
import de.polygonal.zz.texture.Texture;
import nme.display.Graphics;
import nme.display.Tilesheet;
import nme.geom.Rectangle;

class TilesheetRenderer extends Renderer
{
	inline static var NUM_ENTRIES_PER_TILE = 11;
	
	public var context(default, null):Dynamic;
	
	public var numCallsToDrawTiles = 0;
	public var useBatching = true;
	
	var mContext:Graphics;
	var mBuffer:ArrayList<Float>;
	
	var mTilesheetLut:IntHashTable<Tilesheet>;
	var mBatchIntervals:ArrayList<Int>;
	
	var mCurrentTilesheetFlags:Int;
	var mCurrentTilesheet:Tilesheet;
	var mCurrentAlphaBlendMode:AlphaBlendMode;
	
	var mRenderState1:RenderState;
	var mRenderState2:RenderState;
	
	var mTileIndexMap:IntIntHashTable; //texture atlas frame id => index into tilsheet
	
	public function new()
	{
		super();
		
		supportsNonPowerOfTwoTextures = true;
		
		mTilesheetLut = new IntHashTable(256, 256);
		mBatchIntervals = new ArrayList<Int>();
		mBuffer = new ArrayList<Float>(1024);
		mRenderState1 = new RenderState();
		mRenderState2 = new RenderState();
		mTileIndexMap = new IntIntHashTable(1 << 14);
	}
	
	override public function free()
	{
		super.free();
	}
	
	override function onInitRenderContext(handle:Dynamic)
	{
		mContext = handle;
	}
	
	override function clear() 
	{
		mContext.clear();
		numCallsToDrawTiles = 0;
	}
	
	override public function drawVisibleSet(visibleSet:ArrayList<Visual>)
	{
		if (visibleSet.isEmpty()) return;
		
		#if (verbose == "extra")
		L.v('Drawing visible set: count=${visibleSet.size}', "nme");
		#end
		
		if (!useBatching)
		{
			super.drawVisibleSet(visibleSet);
			return;
		}
		
		/* find batch groups */
		
		var indices = mBatchIntervals;
		indices.clear();
		
		var state1 = mRenderState1, state2 = mRenderState2, tmp;
		
		var itr:ArrayListIterator<Visual> = cast visibleSet.iterator();
		
		var a = itr.next(), b;
		
		//find first visual pointing to an effect object
		while (a.effect == null && itr.hasNext()) a = itr.next();
		
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
		
		/* draw batch groups */
		
		var i = 0, k = indices.size, effect, visual, tileIndex, restore;
		while (i < k)
		{
			min = indices.get(i++);
			max = indices.get(i++);
			
			currentVisual = visibleSet.get(min);
			currentEffect = currentVisual.effect;
			assert(currentEffect != null);
			
			setGlobalState(currentVisual);
			
			//alpha blend mode is constant in batch group
			restore = allowedGlobalStates.has(AlphaBlend);
			allowedGlobalStates.unset(AlphaBlend);
			
			switch (currentEffect.type)
			{
				case ColorEffect.TYPE:
					//TODO implement color effect
				
				case TextureEffect.TYPE:
					reserve((max - min) + 1);
					while (min <= max)
					{
						visual = visibleSet.get(min);
						setGlobalState(visual);
						
						effect = visual.effect.as(TextureEffect);
						mCurrentTilesheet = getTilesheet(effect);
						tileIndex = mTileIndexMap.get((effect.getFrameId() << 8) | effect.texture.key);
						mCurrentTilesheetFlags = addTile(tileIndex, effect.cropRectPx, visual.world);
						min++;
					}
					flush();
			}
			
			if (restore) allowedGlobalStates.set(AlphaBlend);
		}
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		mContext.beginFill(effect.color, currentAlphaMultiplier);
		//TODO implement color effect
		mContext.endFill();
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		mCurrentTilesheet = getTilesheet(effect);
		reserve(1);
		var tileIndex = mTileIndexMap.get((effect.getFrameId() << 8) | effect.texture.key);
		mCurrentTilesheetFlags = addTile(tileIndex, effect.cropRectPx, currentVisual.world);
		flush();
	}
	
	override function drawTileMapEffect(effect:TileMapEffect)
	{
	}
	
	override function viewportTransform(output:Vec3)
	{
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
	}
	
	override public function setAlphaBlendState(value:AlphaBlendMode)
	{
		mCurrentAlphaBlendMode = value;
	}
	
	inline function reserve(numTiles:Int)
	{
		mBuffer.reserve(mBuffer.size + numTiles * NUM_ENTRIES_PER_TILE);
	}
	
	function flush()
	{
		var k = mBuffer.size;
		var src = mBuffer.getData();
		var dst = NativeArrayTools.alloc(k);
		NativeArrayTools.blit(src, 0, dst, 0, k);
		
		if (mCurrentAlphaBlendMode == AlphaBlendMode.Add)
			mCurrentTilesheetFlags |= Tilesheet.TILE_BLEND_ADD;
		
		mContext.drawTiles(mCurrentTilesheet, dst, mSmooth, mCurrentTilesheetFlags);
		
		mBuffer.clear();
		numCallsToDrawTiles++;
	}
	
	function addTile(tileIndex:Int, rect:Recti, xform:Xform):Int
	{
		var flags = 0;
		var buf = mBuffer;
		buf.reserve(buf.size + NUM_ENTRIES_PER_TILE);
		inline function add(val) buf.unsafePushBack(val);
		
		var t = xform.getTranslate();
		add(t.x);
		add(t.y);
		add(tileIndex);
		
		var s = xform.getScale();
		var sx = s.x / rect.w;
		var sy = s.y / rect.h;
		
		var scale = !M.cmpAbs(sx, 1., M.EPS) || !M.cmpAbs(sx, 1., M.EPS);
		var rotation = !xform.isIdentityRotation();
		if (scale || rotation)
		{
			flags |= Tilesheet.TILE_TRANS_2x2;
			var m = xform.getMatrix();
			add(m.m11 * sx);
			add(m.m21 * sy);
			add(m.m12 * sx);
			add(m.m22 * sy);
		}
		
		//TODO color transform
		/*if (effectFlags & Effect.EFFECT_COLOR_XFORM > 0)
		{
			flags |= Tilesheet.TILE_RGB;
			var mult = effect.colorXForm.multiplier;
			add(mult.x);
			add(mult.y);
			add(mult.z);
		}*/
		
		if (currentAlphaMultiplier < 1)
		{
			flags |= Tilesheet.TILE_ALPHA;
			add(currentAlphaMultiplier);
		}
		
		return flags;
	}
	
	inline function getTilesheet(effect:TextureEffect):Tilesheet
	{
		var tilesheet = mTilesheetLut.get(effect.texture.key);
		if (tilesheet == null) tilesheet = createTilesheet(effect);
		return tilesheet;
	}
	
	function createTilesheet(effect:TextureEffect):Tilesheet
	{
		var tilesheet = new Tilesheet(effect.texture.imageData);
		var atlas = effect.atlas, rect;
		var key = effect.texture.key;
		
		if (atlas == null)
		{
			#if debug
			var success = mTileIndexMap.setIfAbsent(key, 0);
			assert(success);
			#else
			mTileIndexMap.set(key, 0);
			#end
			
			rect = effect.cropRectPx;
			tilesheet.addTileRect(new Rectangle(rect.x, rect.y, rect.w, rect.h));
		}
		else
		{
			var index = 0;
			for (frame in atlas.getFrames())
			{
				#if debug
				var success = mTileIndexMap.setIfAbsent((frame.id << 8) | key, index++);
				assert(success);
				#else
				mTileIndexMap.set((frame.id << 8) | key, index++);
				#end
				
				rect = frame.texCoordPx;
				tilesheet.addTileRect(new Rectangle(rect.x, rect.y, rect.w, rect.h));
			}
		}
		
		mTilesheetLut.set(key, tilesheet);
		return tilesheet;
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