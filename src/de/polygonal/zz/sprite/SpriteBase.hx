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
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.scene.AlphaMultiplierState;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.GlobalStateType;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Spatial.as;

/**
	Abstract base class for sprite objects.
**/
@:build(de.polygonal.core.macro.IntConsts.build(
[
	IS_DIRTY,
	HINT_ROTATE,
	HINT_SCALE,
	HINT_UNIFORM_SCALE,
	HINT_UNIT_SCALE,
	HINT_SQUARE_SIZE,
	
	IS_ALPHA_DIRTY,
	IS_VISIBILITY_DIRTY
], true, false, "de.polygonal.zz.sprite.SpriteBase"))
@:access(de.polygonal.zz.scene.Spatial)
class SpriteBase
{
	inline static var SCALE_EPS = .001;
	
	public var tickable = true;
	
	var mSpatial:Spatial;
	var mX:Float = 0;
	var mY:Float = 0;
	var mSizeX:Float = 0;
	var mSizeY:Float = 0;
	var mScaleX:Float = 1;
	var mScaleY:Float = 1;
	var mOriginX:Float = 0;
	var mOriginY:Float = 0;
	var mPivotX:Float = 0;
	var mPivotY:Float = 0;
	var mRotation:Float = 0;
	var mAlpha:Float = 1;
	var mVisible:Bool = true;
	var mFlags:Int = 0;
	var mAni:SpriteAni;
	var mBlending:SpriteBlending;
	
	function new(spatial:Spatial)
	{
		mSpatial = spatial;
		mFlags = HINT_UNIFORM_SCALE | HINT_UNIT_SCALE;
		mSpatial.arbiter = this;
		mSpatial.mFlags |= Spatial.IS_COMPOSITE_LOCKED;
	}
	
	public function free()
	{
		remove();
		
		if (mAni != null)
		{
			mAni.free();
			mAni = null;
		}
		
		if (mBlending != null)
		{
			mBlending.mSprite = null;
			mBlending = null;
		}
		mSpatial = null;
	}
	
	/**
		Every Sprite object manages a scene graph node via composition.
	**/
	public var sgn(get_sgn, never):Spatial;
	inline function get_sgn():Spatial return mSpatial;
	
	/**
		Returns true if this object is an instance of the `SpriteGroup` class.
	**/
	inline public function isGroup():Bool return mSpatial.isNode();
	
	public function remove()
	{
		var p = mSpatial.parent;
		if (p != null) p.removeChild(mSpatial);
	}
	
	public var parent(get_parent, set_parent):SpriteGroup;
	inline function get_parent():SpriteGroup
	{
		return mSpatial.parent != null ? as(mSpatial.parent.arbiter, SpriteGroup) : null;
	}
	inline function set_parent(value:SpriteGroup):SpriteGroup
	{
		remove();
		value.addChild(as(mSpatial.arbiter, SpriteBase));
		return value;
	}
	
	public function getRoot():SpriteGroup
	{
		var p = this;
		while (p.parent != null)
			p = p.parent;
		return as(p, SpriteGroup);
	}
	
	public var name(get_name, set_name):String;
	inline function get_name():String return mSpatial.name;
	inline function set_name(value:String):String
	{
		mSpatial.name = value;
		return value;
	}
	
	/**
		The alpha value in the range [0=(fully transparent), 1=(fully opaque)].
	**/
	public var alpha(get_alpha, set_alpha):Float;
	inline function get_alpha():Float return mAlpha;
	function set_alpha(value:Float):Float
	{
		if (mAlpha != value)
		{
			setDirty();
			mFlags |= IS_ALPHA_DIRTY;
		}
		return mAlpha = Mathematics.fclamp(value, 0, 1);
	}
	
	/**
		If false, this sprite is not drawn.
	**/
	public var visible(get_visible, set_visible):Bool;
	inline function get_visible():Bool return mVisible;
	inline function set_visible(value:Bool):Bool
	{
		if (mVisible != value)
		{
			setDirty();
			mFlags |= IS_VISIBILITY_DIRTY;
		}
		return mVisible = value;
	}
	
	/**
		The x coordinate relative to the local coordinates of the parent object.
		By default, sprites are positioned relatively to their top-left corner.
	**/
	public var x(get_x, set_x):Float;
	inline function get_x():Float return mX;
	inline function set_x(value:Float):Float
	{
		if (mX != value)
		{
			mX = value;
			setDirty();
		}
		return value;
	}
	
	/**
		The y coordinate relative to the local coordinates of the parent object.
		By default, sprites are positioned relatively to their top-left corner.
	**/
	public var y(get_y, set_y):Float;
	inline function get_y():Float return mY;
	inline function set_y(value:Float):Float
	{
		if (mY != value)
		{
			mY = value;
			setDirty();
		}
		return value;
	}
	
	/**
		The rotation in degrees relative to the local coordinates of the parent object.
		Positive rotation is clockwise (because the Y axis is pointing down).
	**/
	public var rotation(get_rotation, set_rotation):Float;
	inline function get_rotation():Float return mRotation;
	inline function set_rotation(value:Float):Float
	{
		if (mRotation != value)
		{
			mRotation = value;
			mFlags |= (HINT_ROTATE | IS_DIRTY);
		}
		return value;
	}
	
	/**
		The uniform scale of the object relative to its pivot point.
		Short for using scaleX & scaleY if the scaling values are equal for both axes.
	**/
	public var scale(get_scale, set_scale):Float;
	inline function get_scale():Float
	{
		assert(mFlags & HINT_UNIFORM_SCALE != 0, "scaling is not uniform");
		return mScaleX;
	}
	inline function set_scale(value:Float):Float
	{
		if (mScaleX != value || mScaleY != value)
		{
			mScaleX = mScaleY = value;
			mFlags |= (HINT_SCALE | HINT_UNIFORM_SCALE | IS_DIRTY);
			mFlags &= ~HINT_UNIT_SCALE;
		}
		return value;
	}
	
	/**
		The horizontal scale of the object relative to its pivot point.
		The default value of 1 means no scale, values < 1 makes the sprite smaller, values > 1makes it bigger.
		To mirror a sprite along its x-axis, apply a negative scaling value.
	**/
	public var scaleX(get_scaleX, set_scaleX):Float;
	inline function get_scaleX():Float return mScaleX;
	inline function set_scaleX(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteGroup object only supports uniform scaling.");
		
		if (mScaleX != value)
		{
			mScaleX = value;
			mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
			mFlags |= (HINT_SCALE | IS_DIRTY);
		}
		return value;
	}
	
	/**
		The vertical scale of the object relative to its pivot point.
		The default value of 1 means no scale, values < 1 makes the sprite smaller, values > 1makes it bigger.
		To mirror a sprite along its y-axis, apply a negative scaling value.
	**/
	public var scaleY(get_scaleY, set_scaleY):Float;
	inline function get_scaleY():Float return mScaleY;
	inline function set_scaleY(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteGroup object only supports uniform scaling.");
		
		if (mScaleY != value)
		{
			mScaleY = value;
			mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
			mFlags |= (HINT_SCALE | IS_DIRTY);
		}
		return value;
	}
	
	/**
		The width of this sprite.
		Changing the width affects the scaling factor, e.g. if scaleX equals 1.0 and width equals 100,
		changing the witdh to 50 will set the scaling factor to 0.5. If not desired call bakeDownScale()
		afterwards.
		
		If scaleX == 1, width equals the unscaled texture width in pixels.
	**/
	public var width(get_width, set_width):Float;
	function get_width():Float
	{
		return mSizeX * M.fabs(mScaleX);
	}
	function set_width(value:Float):Float
	{
		assert(mSizeX != 0, "width must not be zero, call setTexture() or setColor() first");
		
		mScaleX = value / mSizeX;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= (HINT_SCALE | IS_DIRTY);
		return value;
	}
	
	/**
		The half-width of this sprite.
	**/
	public var radiusX(get_radiusX, never):Float;
	inline function get_radiusX():Float return width * .5;
	
	/**
		The height of this sprite.
		If scaleY == 1, height equals the unscaled texture height in pixels.
	**/
	public var height(get_height, set_height):Float;
	function get_height():Float
	{
		return mSizeY * M.fabs(mScaleY);
	}
	function set_height(value:Float):Float
	{
		assert(mSizeY != 0, "height must not be zero, call setTexture() or setColor() first");
		mScaleY = value / mSizeY;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= (HINT_SCALE | IS_DIRTY);
		return value;
	}
	
	/**
		The half-height of this sprite.
	**/
	public var radiusY(get_radiusY, never):Float;
	inline function get_radiusY():Float return height * .5;
	
	public var size(get_size, set_size):Float;
	function get_size():Float
	{
		assert(mSizeX == mSizeY, "rectangle is not a square");
		return mSizeX;
	}
	function set_size(value:Float):Float
	{
		assert(mSizeX != 0, "use setColor() or setTexture() to define an initial size");
		assert(mSizeX == mSizeY, "rectangle is not a square");
		mScaleX = mScaleY = value / mSizeX;
		mFlags &= ~HINT_UNIT_SCALE;
		mFlags |= (HINT_SCALE | HINT_UNIFORM_SCALE | IS_DIRTY);
		return value;
	}
	
	/**
		The x coordinate of this object's origin in its local space. Default is 0.
		Changing the origin also changes the visual position of the sprite,
		although its x,y position remains the same.
	**/
	public var originX(get_originX, set_originX):Float;
	inline function get_originX():Float return mOriginX;
	inline function set_originX(value:Float):Float
	{
		mOriginX = value;
		setDirty();
		return value;
	}
	
	/**
		The y coordinate of this object's origin in its local space. Default is 0.
		Changing the origin also changes the visual position of the sprite,
		although its x,y position remains the same.
	**/
	public var originY(get_originY, set_originY):Float;
	inline function get_originY():Float return mOriginX;
	inline function set_originY(value:Float):Float
	{
		mOriginY = value;
		setDirty();
		return value;
	}
	
	/**
		The x coordinate of this object's pivot point in its local space. Default is 0.
		The pivot point defines the object's center point for rotation and scaling.
	 *
		The coordinates of this point must be relative to the top-left corner of the sprite,
		and ignore all transformations (position, scale, rotation), e.g. the pivot point coordinates
		for the bottom-right corner would be (width, height).
	**/
	public var pivotX(get_pivotX, set_pivotX):Float;
	inline function get_pivotX():Float return mPivotX;
	inline function set_pivotX(value:Float):Float
	{
		mPivotX = value;
		setDirty();
		return value;
	}
	
	/**
		The y coordinate of this object's pivot point in its local space. Default is 0.
		The pivot point defines the object's center point for rotation and scaling.
		The coordinates of this point must be relative to the top-left corner of the sprite,
		and ignore all transformations (position, scale, rotation), e.g. the pivot point coordinates
		for the bottom-right corner would be (width, height).
	**/
	public var pivotY(get_pivotY, set_pivotY):Float;
	inline function get_pivotY():Float return mPivotY;
	inline function set_pivotY(value:Float):Float
	{
		mPivotY = value;
		setDirty();
		return value;
	}
	
	/**
		Moves the origin point to the center of this sprite.
		By default, the origin is at the top-left corner.
	**/
	public function centerOrigin()
	{
		originX = -mSizeX / 2;
		originY = -mSizeY / 2;
		setDirty();
	}
	
	/**
		Horizontally centers the origin point of this sprite.
	**/
	public function centerOriginX()
	{
		originX = -mSizeX / 2;
		setDirty();
	}
	
	/**
		Vertically centers the origin point of this sprite.
	**/
	public function centerOriginY()
	{
		originY = -mSizeY / 2;
		setDirty();
	}
	
	/**
		Moves the pivot point from to the center of this sprite.
		By default, the pivot point is at the top-left corner.
	**/
	public function centerPivot()
	{
		mPivotX = mSizeX / 2;
		mPivotY = mSizeY / 2;
		setDirty();
	}
	
	/**
		Horizontally centers the pivot point of this sprite.
	**/
	public function centerPivotX()
	{
		mPivotX = mSizeX / 2;
		setDirty();
	}
	
	/**
		Vertically centers the pivot point of this sprite.
	**/
	public function centerPivotY()
	{
		mPivotY = mSizeY / 2;
		setDirty();
	}
	
	public function centerPivotAndOrigin()
	{
		var cx = mSizeX / 2;
		var cy = mSizeY / 2;
		mPivotX = cx;
		mPivotY = cy;
		originX =-cx;
		originY =-cy;
		setDirty();
	}
	
	inline public function setPosition(x:Float, y:Float)
	{
		mX = x;
		mY = y;
		setDirty();
	}
	
	inline public function setScale(x:Float, y:Float)
	{
		mScaleX = x;
		mScaleY = y;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= (HINT_SCALE | IS_DIRTY);
	}
	
	public function resetOrigin()
	{
		mOriginX = mOriginY = 0;
		setDirty();
	}
	
	public function resetPivot()
	{
		mPivotX = mPivotY = 0;
		setDirty();
	}
	
	public function resetScale()
	{
		mScaleX = mScaleX = 1;
		mFlags &= ~HINT_SCALE;
		mFlags |= HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | IS_DIRTY;
		mSpatial.local.setUnitScale2();
	}
	
	public function resetRotation()
	{
		mRotation = 0;
		mFlags &= ~HINT_ROTATE;
		mSpatial.local.setIdentityRotation();
		setDirty();
	}
	
	public function resetTransformation()
	{
		mX = mSizeX = mPivotX = mOriginX = 0.;
		mY = mSizeY = mPivotY = mOriginY = 0.;
		mScaleX = 1.;
		mScaleY = 1.;
		mRotation = 0;
		mFlags &= ~(HINT_ROTATE | HINT_SCALE);
		mFlags |= (HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mSpatial.local.setIdentity2();
	}
	
	public function getBounds(targetSpace:SpriteBase, output:Aabb2):Aabb2
	{
		if (getDirty()) commit();
		
		return mSpatial.getBoundingBox(targetSpace.sgn, output);
	}
	
	/**
		Converts a point from local coordinates (`input`) to world space coordinates (`output`).
	**/
	public function toWorldSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		if (getDirty()) commit();
		
		return mSpatial.world.applyForward2(input, output);
	}
	
	/**
		Converts a point from world coordinates (`input`) to local space coordinates (`output`).
	**/
	public function toLocalSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		if (getDirty()) commit();
		
		return mSpatial.world.applyInverse2(input, output);
	}
	
	public function tick(timeDelta:Float)
	{
		if (tickable)
			if (mSpatial.controllers != null)
				mSpatial.updateControllers(timeDelta);
	}
	
	inline function updateAlphaAndVisibility()
	{
		if (mFlags & (IS_ALPHA_DIRTY | IS_VISIBILITY_DIRTY) > 0)
		{
			if (mAlpha == 0)
				mSpatial.cullingMode = CullingMode.CullAlways; //always skip rendering
			else
				mSpatial.cullingMode = mVisible ? CullingMode.CullDynamic : CullingMode.CullAlways;
			
			if (mFlags & IS_ALPHA_DIRTY > 0)
			{
				if (mAlpha < 1)
				{
					var state = mSpatial.getGlobalState(GlobalStateType.AlphaMultiplier);
					if (state == null) //create new state
						mSpatial.setGlobalState(new AlphaMultiplierState(mAlpha));
					else
					{
						//update existing state
						state.as(AlphaMultiplierState).value = mAlpha;
					}
				}
				else
				{
					//remove state
					mSpatial.removeGlobalState(GlobalStateType.AlphaMultiplier);
				}
				
				mSpatial.mFlags |= Spatial.IS_RS_DIRTY;
			}
			
			mFlags &= ~(IS_ALPHA_DIRTY | IS_VISIBILITY_DIRTY);
		}
	}
	
	/**
		Updates local transformation.
	**/
	public function commit()
	{
		if (!getDirty()) return;
		clrDirty();
		
		updateAlphaAndVisibility();
		
		invalidateWorldTransform();
		
		//simple brute-force SRT update
		var l = mSpatial.local;
		
		var angle = M.wrap(mRotation, 360) * M.DEG_RAD;
		var s = Math.sin(angle);
		var c = Math.cos(angle);
		var sx = mScaleX;
		var sy = mScaleY;
		sx = clampScale(sx);
		sy = clampScale(sy);
		var spx = sx * mPivotX;
		var spy = sy * mPivotY;
		
		if (isGroup())
		{
			if (sx == sy)
				l.setUniformScale2(sx);
			else
				l.setScale2(sx, sy);
		}
		else
		{
			if (mSizeX == mSizeY && sx == sy)
				l.setUniformScale2(mSizeX * sx);
			else
				l.setScale2(mSizeX * sx, mSizeY * sy);
		}
		
		var m = l.getRotate();
		m.m11 = c; m.m12 =-s;
		m.m21 = s; m.m22 = c;
		l.setRotate(m);
		
		l.setTranslate2
		(
			-(spx * c) + (spy * s) + mPivotX + x + mOriginX,
			-(spx * s) - (spy * c) + mPivotY + y + mOriginY
		);
	}
	
	public var ani(get_ani, set_ani):SpriteAni;
	function get_ani():SpriteAni
	{
		if (mAni == null)
			mAni = new SpriteAni(this);
		return mAni;
	}
	function set_ani(value:SpriteAni):SpriteAni
	{
		if (value == null)
		{
			mAni.free();
			mAni = null;
		}
		return value;
	}
	
	/**
		Specifies which blend mode to use.
	**/
	public var blending(get_blending, set_blending):SpriteBlending;
	function get_blending():SpriteBlending
	{
		if (mBlending == null) mBlending = new SpriteBlending(this);
		return mBlending;
	}
	function set_blending(value:SpriteBlending):SpriteBlending
	{
		if (value == null)
		{
			mBlending.mSprite = null;
			mBlending = null;
		}
		return value;
	}
	
	inline function hasHint(x:Int) return (mFlags & x) > 0;
	inline function clrHint(x:Int) mFlags &= ~x;
	
	inline function setDirty() mFlags |= IS_DIRTY;
	inline function getDirty() return mFlags & IS_DIRTY > 0;
	inline function clrDirty() mFlags &= ~IS_DIRTY;
	
	inline function clampScale(x:Float) return x < 0 ? (x > -SCALE_EPS ? -SCALE_EPS : x) : (x < SCALE_EPS ? SCALE_EPS : x);
	
	inline function invalidateWorldTransform() mSpatial.mFlags |= Spatial.IS_WORLD_XFORM_DIRTY;
}