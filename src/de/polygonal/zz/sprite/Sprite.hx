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
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.render.RenderTarget;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.sprite.SpriteBase;
import de.polygonal.zz.sprite.SpriteBase.*;
import de.polygonal.zz.sprite.SpriteUtil;
import de.polygonal.zz.texture.atlas.TextureAtlas.TextureAtlasFrame;
import de.polygonal.zz.texture.TextureLib;

import de.polygonal.zz.scene.Spatial.as;

//Sets the untransformed size of the node.
//The contentSize remains the same no matter the node is scaled or rotated. All nodes has a size. Layer and Scene has the same size of the screen.
//Parameters
//contentSize	The untransformed size of the node.

/**
	A Sprite is a rectangular, drawable representation of a texture, with its own transformations, color, etc.
**/
@:build(de.polygonal.core.macro.IntConsts.build([HINT_TRIMMED, HAS_SIZE], true, false, "de.polygonal.zz.sprite.SpriteBase"))
@:access(de.polygonal.zz.scene.Spatial)
class Sprite extends SpriteBase
{
	var mVisual:Visual;
	var mTrimRect:Rectf;
	var mCurrentTexture:Int = -1;
	var mCurrentFrame:String;
	var mSize = new Sizef(0, 0);
	
	public function new(?parent:SpriteGroup)
	{
		super(new Quad());
		mVisual = as(mSpatial, Visual);
		if (parent != null) parent.addChild(this);
	}
	
	override public function free()
	{
		super.free();
		
		mVisual.free();
		mVisual = null;
		mTrimRect = null;
		mCurrentTexture = -1;
		mCurrentFrame = null;
		mSize = null;
	}
	
	/**
		Assigning a new texture clears the current frame.
	**/
	public var texture(get_texture, set_texture):Int;
	function get_texture():Int
	{
		return mCurrentTexture;
	}
	
	function set_texture(id:Int):Int
	{
		if (mCurrentTexture == id) return id;
		mCurrentTexture = id;
		
		mCurrentFrame = null;
		
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
		
		var texture = TextureLib.getTexture(id);
		e.setTexture(texture, texture.atlas);
		
		mSize.set(mSizeX, mSizeY);
		mSizeX = e.texture.sourceSize.x;
		mSizeY = e.texture.sourceSize.y;
		setSquareHint(mSizeX, mSizeY);
		mFlags &= ~HINT_TRIMMED;
		mFlags |= HAS_SIZE;
		setDirty();
		
		return id;
	}
	
	public var frame(get_frame, set_frame):String;
	inline function get_frame():String return mCurrentFrame;
	function set_frame(name:String):String
	{
		assert(mCurrentTexture != -1, "no texture assigned");
		assert(TextureLib.getTexture(mCurrentTexture).atlas != null, "current texture has no texture atlas definition");
		
		if (mCurrentFrame == name) return name; //no change
		mCurrentFrame = name;
		
		//change frame
		var e = mVisual.effect.as(TextureEffect);
		
		var frame = e.atlas.getFrameBy(name);
		e.setFrameIndex(frame.index); //change uv coordinates
		
		var size = frame.untrimmedSize;
		mSizeX = size.x;
		mSizeY = size.y;
		
		if (frame.trimmed)
		{
			//opaque region is trimmed
			mFlags |= HINT_TRIMMED;
			
			var t = frame.trimOffset;
			var u = frame.texCoordPx;  //cr e.atlas.getSizeAt(frame);
			
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
		
		if (e.atlas.scale != 1.)
		{
			//for low-res texture, scaleFactor is < 1.
			//to end up with the same size, we need to multiply by the inverse.
			var invScale = 1 / e.atlas.scale;
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
		
		setDirty();
		
		return name;
	}
	
	public var color(get_color, set_color):Int;
	function get_color():Int
	{
		return mVisual.effect.as(ColorEffect).color;
	}
	function set_color(value:Int):Int
	{
		mVisual.effect = new ColorEffect(value); //todo reuse effect if changing color..
		return value;
	}
	
	/**
		The original, unscaled dimensions of this sprite as defined by the texture.
	**/
	public function getContentSize():Sizef
	{
		return mSize.set(mSizeX, mSizeY);
	}
	
	public function setContentSize(width:Float, height:Float)
	{
		mSizeX = width;
		mSizeY = height;
		setSquareHint(width, height);
		mFlags &= ~HINT_TRIMMED;
		
		if (width == 0 || height == 0)
			mFlags &= ~HAS_SIZE;
		else
			mFlags |= HAS_SIZE;
		
		setDirty();
	}
	
	/**
		Multiplies the size of this sprite with its scale factor and sets the scale to 1.
	**/
	public function bakeDownScale()
	{
		mSizeX *= M.fabs(mScaleX);
		mSizeY *= M.fabs(mScaleY);
		mScaleX = 1;
		mScaleY = 1;
		mFlags &= ~HINT_SCALE;
		mFlags |= (HINT_UNIFORM_SCALE | IS_DIRTY);
	}
	
	public function hitTestPoint(point:Coord2f):Bool
	{
		//TODO commit -make sure xforms are current
		
		return getVisual().pick(point, null) == 1;
	}
	
	override public function getBound(targetSpace:SpriteBase, output:Aabb2):Aabb2
	{
		if (this == targetSpace)
		{
			output.x = originX;
			output.y = originY;
			output.w = mSizeX;
			output.h = mSizeY;
			return output;
		}
		
		var r = getRoot();
		r.commit();
		
		TreeUtil.updateGeometricState(as(r.sgn, Node), false);
		
		return mSpatial.getBoundingBox(targetSpace.sgn, output);
		
		//if this is a descedent of targetSpace
		
		//different parent??
		
		/*var g = targetSpace.asGroup();
		
		var p = parent;
		while (p != null)
		{
			if (p == g)
			{
				SpriteUtil.update(g);
				NodeUtil.updateGeometricState(as(g.sgn, Node));
				trace('target space is a parent of $this');
				break;
			}
			p = p.parent;
		}*/
		
		//if this is a node and targetspace is a parent of this, faster update
		/*var isDescendant = false;
		var p = targetSpace.parent;
		while (p != null)
		{
			//if (p == this)
			//{
				//isDescendant = true;
				//break;
			//}
			p = p.parent;
		}
		if (isDescendant)
		{
			trace('targetSpace is a child of this!');
			//optimization possible here?
		}*/
		
		//if targetSpace is a child of this,
	}
	
	public function localBound():Rectf
	{
		commit();
		
		//var bv = new Bv();
		//getVisual().modelBound.transformBy(mSpatial.local, bv);
		//trace(bv);
		
		return null;
	}
	
	public function worldBound():Rectf
	{
		
		return null;
	}
	
	override public function commit()
	{
		if (mFlags & HAS_SIZE == 0) return;
		
		if (!getDirty()) return;
		clrDirty();
		
		updateAlphaAndVisibility();
		
		invalidateWorldTransform();
		
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
			
			var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_SQUARE_SIZE);
			if (hints & HINT_ROTATE > 0)
			{
				/* rotate and scale around pivot point
				|1 0 x+px| |cosΦ -sinΦ 0| |s2x   0 0| |1 0 -px| |s1x   0 0|
				|0 1 y+py| |sinΦ  cosΦ 0| |  0 s2y 0| |0 1 -py| |0   s1y 0|
				=
				|s1x*s2x*c -s1y*s2y*s -s2x*px*c + s2y*py*s + px+x|
				|s1x*s2x*s  s1y*s2y*c -s2x*px*s - s2y*py*c + py+y|
				*/
				
				var angle = mRotation * M.DEG_RAD;
				var s = Math.sin(angle);
				var c = Math.cos(angle);
				var m = l.getRotate();
				m.m11 = c; m.m12 =-s;
				m.m21 = s; m.m22 = c;
				l.setRotate(m);
				
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R, S = I
					if (hints & HINT_SQUARE_SIZE > 0)
						l.setUniformScale2(mTrimRect.w);
					else
						l.setScale2(mTrimRect.w, mTrimRect.h);
					
					l.setTranslate2
					(
						-(px * c) + (py * s) + px + x + mOriginX + mTrimRect.x,
						-(px * s) - (py * c) + py + y + mOriginY + mTrimRect.y
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
						
						if (hints & HINT_SQUARE_SIZE > 0)
							l.setUniformScale2(mTrimRect.w * su);
						else
							l.setScale2(mTrimRect.w * su, mTrimRect.h * su);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x + mOriginX + mTrimRect.x,
							-(spx * s) - (spy * c) + py + y + mOriginY + mTrimRect.y
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
							-(spx * c) + (spy * s) + px + x + mOriginX + mTrimRect.x,
							-(spx * s) - (spy * c) + py + y + mOriginY + mTrimRect.y
						);
					}
				}
			}
			else
			{
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R = I, S = I
					if (hints & HINT_SQUARE_SIZE > 0)
						l.setUniformScale2(mTrimRect.w);
					else
						l.setScale2(mTrimRect.w, mTrimRect.h);
					
					l.setTranslate2
					(
						x + mOriginX + mTrimRect.x,
						y + mOriginY + mTrimRect.y
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
						
						if (hints & HINT_SQUARE_SIZE > 0)
							l.setUniformScale2(mTrimRect.w * su);
						else
							l.setScale2(mTrimRect.w * su, mTrimRect.h * su);
						
						l.setTranslate2
						(
							-(su * px) + px + x + mOriginX + mTrimRect.x,
							-(su * py) + py + y + mOriginY + mTrimRect.y
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
							-(sx * px) + px + x + mOriginX + mTrimRect.x,
							-(sy * py) + py + y + mOriginY + mTrimRect.y
						);
					}
				}
			}
		}
		else
		{
			var px = mPivotX;
			var py = mPivotY;
			
			var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_SQUARE_SIZE);
			if (hints & HINT_ROTATE > 0)
			{
				//rotate and scale around pivot point
				var angle = mRotation * M.DEG_RAD;
				var s = Math.sin(angle);
				var c = Math.cos(angle);
				var m = l.getRotate();
				m.m11 = c; m.m12 =-s;
				m.m21 = s; m.m22 = c;
				l.setRotate(m);
				
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R, S = I
					if (hints & HINT_SQUARE_SIZE > 0)
						l.setUniformScale2(mSizeX);
					else
						l.setScale2(mSizeX, mSizeY);
					
					l.setTranslate2
					(
						-(px * c) + (py * s) + px + x + mOriginX,
						-(px * s) - (py * c) + py + y + mOriginY
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
						
						if (hints & HINT_SQUARE_SIZE > 0)
							l.setUniformScale2(mSizeX * su);
						else
							l.setScale2(mSizeX * su, mSizeY * su);
						
						l.setTranslate2
						(
							-(spx * c) + (spy * s) + px + x + mOriginX,
							-(spx * s) - (spy * c) + py + y + mOriginY
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
							-(spx * c) + (spy * s) + px + x + mOriginX,
							-(spx * s) - (spy * c) + py + y + mOriginY
						);
					}
				}
			}
			else
			{
				if (hints & HINT_UNIT_SCALE > 0)
				{
					//R = I, S = I
					if (hints & HINT_SQUARE_SIZE > 0)
						l.setUniformScale2(mSizeX);
					else
						l.setScale2(mSizeX, mSizeY);
					
					l.setTranslate2
					(
						x + mOriginX,
						y + mOriginY
					);
				}
				else
				{
					//scale around pivot point
					if (hints & HINT_UNIFORM_SCALE > 0)
					{
						//R = I, S = cI
						var su = clampScale(mScaleX);
						
						if (hints & HINT_SQUARE_SIZE > 0)
							l.setUniformScale2(mSizeX * su);
						else
							l.setScale2(mSizeX * su, mSizeY * su);
						
						l.setTranslate2
						(
							-(su * px) + px + x + mOriginX,
							-(su * py) + py + y + mOriginY
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
							-(sx * px) + px + x + mOriginX,
							-(sy * py) + py + y + mOriginY
						);
					}
				}
			}
		}
	}
	
	inline public function sendToForeground()
	{
		if (parent != null) parent.sendToForeground(this);
	}
	
	inline public function sendToBackground()
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
		input.x = x;
		input.y = y;
		return output;
	}
	
	override public function toLocalSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		super.toLocalSpace(input, output);
		output.x *= mSizeX;
		output.y *= mSizeY;
		return output;
	}
	
	inline function setSquareHint(sx:Float, sy:Float) sx == sy ? mFlags |= HINT_SQUARE_SIZE : mFlags &= ~HINT_SQUARE_SIZE;
	
	inline function getVisual():Visual return mVisual;
}