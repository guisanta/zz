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
package de.polygonal.zz.sprite;

import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Coord2;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.math.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.sprite.SpriteBase;
import de.polygonal.zz.sprite.SpriteBase.*;
import de.polygonal.zz.texture.TextureLib;

/**
	A Sprite is a rectangular, drawable representation of a texture, with its own transformations, color, etc.
**/
@:access(de.polygonal.zz.scene.Spatial)
class Sprite extends SpriteBase
{
	inline static var HINT_SIZE = 0x80;
	inline static var HINT_SQUARE = 0x100;
	inline static var HINT_TRIMMED = 0x200;
	
	inline public static var TYPE = 1;
	
	inline public static var FLAG_TRIM = 0x01;
	inline static var FLAG_SKIP_UNTRIM = 0x02;
	inline static var FLAG_SKIP_WORLD_UPDATE = 0x04;
	
	public static var MAX_POOL_SIZE = 256;
	
	static var _pool:ArrayList<Sprite>;
	
	public static function get(?parent:SpriteGroup, ?textureId:Null<Int>, ?frame:String):Sprite
	{
		if (_pool == null) _pool = new ArrayList<Sprite>(64);
		
		var sprite = _pool.size > 0 ? _pool.popBack() : new Sprite();
		
		if (parent != null) parent.addChild(sprite);
		
		if (textureId != null)
			sprite.setTexture(textureId, frame);
		return sprite;
	}
	
	public static function put(sprite:Sprite)
	{
		if (_pool == null) _pool = new ArrayList<Sprite>(64);
		
		if (_pool.size == MAX_POOL_SIZE)
		{
			sprite.free();
			return;
		}
		
		sprite.sheetAni.stop();
		
		sprite.remove();
		sprite.resetTransformation();
		sprite.blending.setInherit();
		sprite.alpha = 1;
		sprite.visible = true;
		
		_pool.pushBack(sprite);
	}
	
	var mSizeX = 0.;
	var mSizeY = 0.;
	
	var mVisual:Quad;
	var mTrimRect:Rectf;
	var mCurrentTexture = -1;
	var mCurrentFrameName:String;
	var mSheetAni:SpriteSheetAni = null;
	
	public function new(?parent:SpriteGroup, ?textureId:Null<Int>, ?frame:String)
	{
		super(mVisual = new Quad());
		type = TYPE;
		
		if (parent != null) parent.addChild(this);
		if (textureId != null) setTexture(textureId);
		if (frame != null) this.frame = frame;
	}
	
	override public function free()
	{
		if (mSpatial == null) return;
		
		super.free();
		if (mSheetAni != null)
		{
			mSheetAni.free();
			mSheetAni = null;
		}
		
		mVisual.free();
		mVisual = null;
		mTrimRect = null;
		mCurrentTexture = -1;
		mCurrentFrameName = null;
	}
	
	/**
		The width of this sprite.
		Changing the width affects the scaling factor, e.g. if scaleX equals 1.0 and width equals 100,
		changing the witdh to 50 will set the scaling factor to 0.5.
		
		If scaleX == 1, `width` equals the unscaled texture width in pixels.
	**/
	override function get_width():Float
	{
		if (mFlags & HINT_ROTATE == 0) return mSizeX * M.fabs(mScaleX);
		
		//refit axis-aligned box to oriented box
		var ex = mSizeX * M.fabs(mScaleX) / 2;
		var ey = mSizeY * M.fabs(mScaleY) / 2;
		
		var r = getAngle();
		var m12 = -Math.sin(r);
		var m11 =  Math.cos(r);
		var min = 0.;
		var max = 0.;
		
		if (m11 > 0)
		{
			min -= m11 * ex;
			max += m11 * ex;
		}
		else
		{
			min += m11 * ex;
			max -= m11 * ex;
		}
		if (m12 > 0)
		{
			min -= m12 * ey;
			max += m12 * ey;
		}
		else
		{
			min += m12 * ey;
			max -= m12 * ey;
		}
		return max - min;
	}
	override function set_width(value:Float):Float
	{
		assert(Math.isFinite(value));
		assert(mSizeX != 0, "width must not be zero, call setTexture() or setColor() first");
		
		mScaleX = value / mSizeX;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= HINT_SCALE | HINT_LOCAL_DIRTY;
		return value;
	}
	
	/**
		The height of this sprite.
		
		If scaleY == 1, height equals the unscaled texture height in pixels.
	**/
	override function get_height():Float
	{
		if (mFlags & HINT_ROTATE == 0) return mSizeY * M.fabs(mScaleY);
		
		//refit axis-aligned box to oriented box
		var ex = mSizeX * M.fabs(mScaleX) / 2;
		var ey = mSizeY * M.fabs(mScaleY) / 2;
		
		var r = getAngle();
		var m21 = Math.sin(r);
		var m22 = Math.cos(r);
		var min = 0.;
		var max = 0.;
		
		if (m21 > 0)
		{
			min -= m21 * ex;
			max += m21 * ex;
		}
		else
		{
			min += m21 * ex;
			max -= m21 * ex;
		}
		if (m22 > 0)
		{
			min -= m22 * ey;
			max += m22 * ey;
		}
		else
		{
			min += m22 * ey;
			max -= m22 * ey;
		}
		return max - min;
	}
	override function set_height(value:Float):Float
	{
		assert(Math.isFinite(value));
		assert(mSizeY != 0, "height must not be zero, call setTexture() or setColor() first");
		mScaleY = value / mSizeY;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= HINT_SCALE | HINT_LOCAL_DIRTY;
		return value;
	}
	
	public var contentWidth(get, never):Float;
	inline function get_contentWidth():Float return mSizeX;
	
	public var contentHeight(get, never):Float;
	inline function get_contentHeight():Float return mSizeY;
	
	/**
		The original, untransformed size of this sprite as defined by the texture/color.
	**/
	public function getContentSize():Sizef
	{
		return new Coord2f(mSizeX, mSizeY);
	}
	
	override public function centerPivot()
	{
		mPivotX = mSizeX / 2;
		mPivotY = mSizeY / 2;
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	public function getTexture():Int
	{
		return mCurrentTexture;
	}
	
	/**
		Assigning a new texture clears the current frame.
	**/
	public function setTexture(textureId:Int, ?frame:String)
	{
		if (mCurrentTexture == textureId) return;
		
		mCurrentTexture = textureId;
		
		mCurrentFrameName = null;
		
		//create/reuse texture effect
		var e:TextureEffect;
		if (mVisual.effect == null)
		{
			e = new TextureEffect();
			mVisual.effect = e;
		}
		else
		{
			if (mVisual.effect.type == TextureEffect.TYPE)
				e = mVisual.effect.as(TextureEffect);
			else
			{
				mVisual.effect.free();
				e = new TextureEffect();
				mVisual.effect = e;
			}
		}
		
		var texture = TextureLib.getTexture(textureId);
		e.setTexture(texture, texture.atlas);
		
		mSizeX = e.texture.sourceSize.x;
		mSizeY = e.texture.sourceSize.y;
		
		if (frame == null)
		{
			mSizeX *= texture.scale;
			mSizeY *= texture.scale;
		}
		
		setSquareHint(mSizeX, mSizeY);
		mFlags &= ~HINT_TRIMMED;
		mFlags |= HINT_SIZE | HINT_LOCAL_DIRTY;
		
		if (frame != null) set_frame(frame);
	}
	
	public var frame(get, set):String;
	inline function get_frame():String return mCurrentFrameName;
	function set_frame(name:String):String
	{
		assert(name != null);
		
		if (mCurrentFrameName != name)
		{
			mCurrentFrameName = name;
			var effect = mVisual.effect.as(TextureEffect);
			var frame = effect.atlas.getFrameByName(name);
			setFrameIndex(frame.index);
		}
		return name;
	}
	
	public function getColor():Int
	{
		if (mVisual.effect == null) return -1;
		var e = mVisual.effect.as(ColorEffect);
		if (e == null) return -1;
		return e.color;
	}
	
	public function setColor(value:Int, contentSize:Coord2f)
	{
		mSizeX = contentSize.x;
		mSizeY = contentSize.y;
		setSquareHint(mSizeX, mSizeY);
		mFlags &= ~HINT_TRIMMED;
		mFlags |= HINT_SIZE | HINT_LOCAL_DIRTY;
		
		if (mCurrentTexture == -1)
		{
			if (mVisual.effect == null)
				mVisual.effect = new ColorEffect(value);
			
			var e = as(mVisual.effect, ColorEffect);
			e.color = value;
		}
		else
		{
			mCurrentTexture = -1;
			mCurrentFrameName = null;
			
			mVisual.effect.free();
			mVisual.effect = new ColorEffect(value);
		}
	}
	
	public var sheetAni(get, never):SpriteSheetAni;
	function get_sheetAni():SpriteSheetAni
	{
		if (mSheetAni == null) mSheetAni = new SpriteSheetAni(this);
		return mSheetAni;
	}
	
	public function pick(point:Coord2f):Bool
	{
		SpriteTools.updateWorldTransform(this);
		if (sgn.mFlags & SpatialFlags.IS_WORLD_BOUND_DIRTY > 0) sgn.updateWorldBound();
		return mVisual.pick(point, null) == 1;
	}
	
	override public function getBounds(targetSpace:SpriteBase, ?output:Aabb2, ?flags:Int = 0):Aabb2
	{
		if (output == null) output = new Aabb2();
		
		var trimmed = (mFlags & HINT_TRIMMED > 0) && (flags & (FLAG_SKIP_UNTRIM | FLAG_TRIM) == 0);
		if (trimmed) unTrim();
		
		if (flags & FLAG_SKIP_WORLD_UPDATE == 0)
		{
			SpriteTools.updateWorldTransform(this);
			if (SpriteTools.isAncestor(this, targetSpace) == false)
				SpriteTools.updateWorldTransform(targetSpace);
		}

		var bounds = mSpatial.getBoundingBox(targetSpace.sgn, output);
		
		if (trimmed) reTrim();
		
		return bounds;
	}
	
	override public function syncLocal():SpriteBase
	{
		if (mFlags & HINT_SIZE == 0) return this;
		return super.syncLocal();
	}
	
	public function sendToForeground()
	{
		if (parent != null) parent.sendToForeground(this);
	}
	
	public function sendToBackground()
	{
		if (parent != null) parent.sentToBackground(this);
	}
	
	override public function toWorldSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		var x = input.x;
		var y = input.y;
		input.x /= mSizeX;
		input.y /= mSizeY;
		super.toWorldSpace(input, output);
		return output;
	}
	
	override public function toLocalSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		super.toLocalSpace(input, output);
		output.x *= mSizeX;
		output.y *= mSizeY;
		return output;
	}
	
	public var uniformSize(get, set):Float;
	inline function get_uniformSize():Float
	{
		assert(mSizeX == mSizeY, "rectangle is not a square");
		
		return mSizeX;
	}
	function set_uniformSize(value:Float):Float
	{
		assert(mSizeX != 0, "no size defined");
		assert(mSizeX == mSizeY, "rectangle is not a square");
		
		mScaleX = mScaleY = value / mSizeX;
		mFlags &= ~HINT_UNIT_SCALE;
		mFlags |= (HINT_SCALE | HINT_UNIFORM_SCALE | HINT_LOCAL_DIRTY);
		return value;
	}
	
	override function updateLocalTransform()
	{
		mFlags &= ~HINT_LOCAL_DIRTY;
		mSpatial.mFlags |= SpatialFlags.IS_WORLD_XFORM_DIRTY;
		
		/* SRT update:
		 -always apply translation and origin
		 -skip rotation if R=I
		 -skip pivot if R=I and S=I
		 -differ between non-uniform and uniform scaling
		*/
		var l = mSpatial.local;
		
		if (mFlags & HINT_TRIMMED > 0)
		{
			var px = mPivotX - mTrimRect.x;
			var py = mPivotY - mTrimRect.y;
			
			var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_SQUARE);
			if (hints & HINT_ROTATE > 0)
			{
				/* rotate and scale around pivot point
				|1 0 x+px| |cosΦ -sinΦ 0| |s2x   0 0| |1 0 -px| |s1x   0 0|
				|0 1 y+py| |sinΦ  cosΦ 0| |  0 s2y 0| |0 1 -py| |0   s1y 0|
				=
				|s1x*s2x*c -s1y*s2y*s -s2x*px*c + s2y*py*s + px+x|
				|s1x*s2x*s  s1y*s2y*c -s2x*px*s - s2y*py*c + py+y|
				*/
				var angle = getAngle();
				var s = Math.sin(angle);
				var c = Math.cos(angle);
				var m = l.getRotate();
				m.m11 = c; m.m12 =-s;
				m.m21 = s; m.m22 = c;
				l.setRotate(m);
				
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R, S = I
					if (hints & HINT_SQUARE > 0)
						l.setUniformScale2(mTrimRect.w);
					else
						l.setScale2(mTrimRect.w, mTrimRect.h);
					
					l.setTranslate2
					(
						-(px * c) + (py * s) + px + x - mOriginX + mTrimRect.x,
						-(px * s) - (py * c) + py + y - mOriginY + mTrimRect.y
					);
				}
				else
				{
					if (hints & HINT_UNIFORM_SCALE > 0)
					{
						//R, S = cI
						var su = clampScale(mScaleX);
						var spx = su * px;
						var spy = su * py;
						
						if (hints & HINT_SQUARE > 0)
							l.setUniformScale2(mTrimRect.w * su);
						else
							l.setScale2(mTrimRect.w * su, mTrimRect.h * su);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x - mOriginX + mTrimRect.x,
							-(spx * s) - (spy * c) + py + y - mOriginY + mTrimRect.y
						);
					}
					else
					{
						//R, S
						var sx = clampScale(mScaleX);
						var sy = clampScale(mScaleY);
						var spx = sx * px;
						var spy = sy * py;
						
						l.setScale2(mTrimRect.w * sx, mTrimRect.h * sy);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x - mOriginX + mTrimRect.x,
							-(spx * s) - (spy * c) + py + y - mOriginY + mTrimRect.y
						);
					}
				}
			}
			else
			{
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R = I, S = I
					if (hints & HINT_SQUARE > 0)
						l.setUniformScale2(mTrimRect.w);
					else
						l.setScale2(mTrimRect.w, mTrimRect.h);
					
					l.setTranslate2
					(
						x - mOriginX + mTrimRect.x,
						y - mOriginY + mTrimRect.y
					);
				}
				else
				{
					/* scale around pivot point
					|1 0 x+px| |s2x   0 0| |1 0 -px| |s1x   0 0|
					|0 1 y+py| |  0 s2y 0| |0 1 -py| |  0 s1y 0|
					=
					|s1x*s2x        0 -sx*px + px+x|
					|      0  s1y*s2y -sy*py + py+y|
					*/
					
					if (hints & HINT_UNIFORM_SCALE > 0)
					{
						//R = I, S = cI
						var su = clampScale(mScaleX);
						
						if (hints & HINT_SQUARE > 0)
							l.setUniformScale2(mTrimRect.w * su);
						else
							l.setScale2(mTrimRect.w * su, mTrimRect.h * su);
						
						l.setTranslate2
						(
							-(su * px) + px + x - mOriginX + mTrimRect.x,
							-(su * py) + py + y - mOriginY + mTrimRect.y
						);
					}
					else
					{
						//S
						var sx = clampScale(mScaleX);
						var sy = clampScale(mScaleY);
						
						l.setScale2(mTrimRect.w * sx, mTrimRect.h * sy);
						
						l.setTranslate2
						(
							-(sx * px) + px + x - mOriginX + mTrimRect.x,
							-(sy * py) + py + y - mOriginY + mTrimRect.y
						);
					}
				}
			}
		}
		else
		{
			var px = mPivotX;
			var py = mPivotY;
			
			var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_SQUARE);
			if (hints & HINT_ROTATE > 0)
			{
				//rotate and scale around pivot point
				var angle = getAngle();
				var s = Math.sin(angle);
				var c = Math.cos(angle);
				var m = l.getRotate();
				m.m11 = c; m.m12 =-s;
				m.m21 = s; m.m22 = c;
				l.setRotate(m);
				
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R, S = I
					if (hints & HINT_SQUARE > 0)
						l.setUniformScale2(mSizeX);
					else
						l.setScale2(mSizeX, mSizeY);
					
					l.setTranslate2
					(
						-(px * c) + (py * s) + px + x - mOriginX,
						-(px * s) - (py * c) + py + y - mOriginY
					);
				}
				else
				{
					if (hints & HINT_UNIFORM_SCALE > 0)
					{
						//R, S = cI
						var su = clampScale(mScaleX);
						var spx = su * px;
						var spy = su * py;
						
						if (hints & HINT_SQUARE > 0)
							l.setUniformScale2(mSizeX * su);
						else
							l.setScale2(mSizeX * su, mSizeY * su);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x - mOriginX,
							-(spx * s) - (spy * c) + py + y - mOriginY
						);
					}
					else
					{
						//R, S
						var sx = clampScale(mScaleX);
						var sy = clampScale(mScaleY);
						var spx = sx * px;
						var spy = sy * py;
						
						l.setScale2(mSizeX * sx, mSizeY * sy);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x - mOriginX,
							-(spx * s) - (spy * c) + py + y - mOriginY
						);
					}
				}
			}
			else
			{
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R = I, S = I
					if (hints & HINT_SQUARE > 0)
						l.setUniformScale2(mSizeX);
					else
						l.setScale2(mSizeX, mSizeY);
					
					l.setTranslate2
					(
						x - mOriginX,
						y - mOriginY
					);
				}
				else
				{
					//scale around pivot point
					if (hints & HINT_UNIFORM_SCALE > 0)
					{
						//R = I, S = cI
						var su = clampScale(mScaleX);
						
						if (hints & HINT_SQUARE > 0)
							l.setUniformScale2(mSizeX * su);
						else
							l.setScale2(mSizeX * su, mSizeY * su);
						
						l.setTranslate2
						(
							-(su * px) + px + x - mOriginX,
							-(su * py) + py + y - mOriginY
						);
					}
					else
					{
						//S
						var sx = clampScale(mScaleX);
						var sy = clampScale(mScaleY);
						
						l.setScale2(mSizeX * sx, mSizeY * sy);
						
						l.setTranslate2
						(
							-(sx * px) + px + x - mOriginX,
							-(sy * py) + py + y - mOriginY
						);
					}
				}
			}
		}
	}
	
	function setFrameIndex(index:Int)
	{
		//set spritesheet frame
		assert(mCurrentTexture != -1, "no texture assigned");
		assert(TextureLib.getTexture(mCurrentTexture).atlas != null, "current texture has no texture atlas definition");
		
		var effect = mVisual.effect.as(TextureEffect);
		effect.setFrameIndex(index); //change uv coordinates
		
		var frame = effect.atlas.getFrameAtIndex(index);
		mSizeX = frame.sourceSize.x;
		mSizeY = frame.sourceSize.y;
		
		if (frame.trimmed)
		{
			//opaque region is trimmed
			mFlags |= HINT_TRIMMED;
			
			var t = frame.trimOffset;
			var u = frame.texCoordPx;
			
			if (mTrimRect == null)
				mTrimRect = new Rectf(t.x, t.y, u.w, u.h);
			else
			{
				mTrimRect.x = t.x;
				mTrimRect.y = t.y;
				mTrimRect.w = u.w;
				mTrimRect.h = u.h;
			}
			
			setSquareHint(u.w, u.h);
		}
		else
		{
			mFlags &= ~HINT_TRIMMED;
			setSquareHint(mSizeX, mSizeY);
		}
		
		if (effect.atlas.scale != 1.)
		{
			//for low-res texture, scaleFactor is < 1.
			//to end up with the same size, we need to multiply by the inverse.
			var invScale = 1 / effect.atlas.scale;
			mSizeX *= invScale;
			mSizeY *= invScale;
			
			if (frame.trimmed)
			{
				mTrimRect.x *= invScale;
				mTrimRect.y *= invScale;
				mTrimRect.w *= invScale;
				mTrimRect.h *= invScale;
			}
		}
		
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	inline function unTrim()
	{
		assert(mVisual.effect.as(TextureEffect).atlas.getFrameByName(mCurrentFrameName).trimmed);
		assert(mFlags <= 0xffff);
		
		mFlags |= mFlags << 16; //make copy
		mFlags |= HINT_LOCAL_DIRTY;
		mFlags &= ~HINT_TRIMMED;
		setSquareHint(mSizeX, mSizeY);
	}
	
	inline function reTrim()
	{
		assert(mVisual.effect.as(TextureEffect).atlas.getFrameByName(mCurrentFrameName).trimmed);
		
		mFlags >>>= 16; //restore copy
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	inline function setSquareHint(w:Float, h:Float) w == h ? mFlags |= HINT_SQUARE : mFlags &= ~HINT_SQUARE;
}