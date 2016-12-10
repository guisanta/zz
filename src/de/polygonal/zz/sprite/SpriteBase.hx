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
import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Mathematics;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.scene.AlphaMultiplierState;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.GlobalStateType;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.scene.SpatialFlags.*;

/**
	Abstract base class for sprite objects.
**/
@:access(de.polygonal.zz.scene.Spatial)
class SpriteBase
{
	inline static var HINT_LOCAL_DIRTY = 0x01;
	inline static var HINT_ALPHA_DIRTY = 0x02;
	inline static var HINT_VISIBILITY_DIRTY = 0x04;
	inline static var HINT_ROTATE = 0x08;
	inline static var HINT_SCALE = 0x10;
	inline static var HINT_UNIFORM_SCALE = 0x20;
	inline static var HINT_UNIT_SCALE = 0x40;
	
	public static var gc = false; //flag is raised every time free() is called
	
	inline static var SCALE_EPS = .001;
	
	public var type(default, null):Int;
	
	var mSpatial:Spatial;
	var mX = 0.;
	var mY = 0.;
	var mScaleX = 1.;
	var mScaleY = 1.;
	var mOriginX = 0.;
	var mOriginY = 0.;
	var mPivotX = 0.;
	var mPivotY = 0.;
	var mRotation = 0.;
	var mAlpha = 1.;
	var mVisible = true;
	var mFlags = HINT_UNIFORM_SCALE | HINT_UNIT_SCALE;
	var mTweenAni:SpriteTweenAni = null;
	var mKeyframeAni:SpriteKeyframeAni = null;
	var mBlending:SpriteBlending;
	
	function new(spatial:Spatial)
	{
		mSpatial = spatial;
		mSpatial.arbiter = this;
	}
	
	public function free()
	{
		remove();
		
		if (mTweenAni != null)
		{
			mTweenAni.free();
			mTweenAni = null;
		}
		
		if (mKeyframeAni != null)
		{
			mKeyframeAni.free();
			mKeyframeAni = null;
		}
		
		if (mBlending != null)
		{
			mBlending.mSprite = null;
			mBlending = null;
		}
		mSpatial = null;
		
		gc = true;
	}
	
	/**
		Every Sprite object manages a scene graph node via composition.
	**/
	public var sgn(get, never):Spatial;
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
	
	public var parent(get, set):SpriteGroup;
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
		while (p.parent != null) p = p.parent;
		return as(p, SpriteGroup);
	}
	
	public var name(get, set):String;
	inline function get_name():String return mSpatial.name;
	inline function set_name(value:String):String
	{
		mSpatial.name = value;
		return value;
	}
	
	/**
		The alpha value in the range [0=(fully transparent), 1=(fully opaque)].
	**/
	public var alpha(get, set):Float;
	inline function get_alpha():Float return mAlpha;
	function set_alpha(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mAlpha != value)
		{
			mAlpha = Mathematics.fclamp(value, 0, 1);
			mFlags |= HINT_ALPHA_DIRTY;
		}
		return mAlpha;
	}
	
	/**
		If false, this sprite is not drawn.
	**/
	public var visible(get, set):Bool;
	inline function get_visible():Bool return mVisible;
	inline function set_visible(value:Bool):Bool
	{
		if (mVisible != value)
		{
			mVisible = value;
			mFlags |= HINT_VISIBILITY_DIRTY;
		}
		return value;
	}
	
	/**
		The x coordinate relative to the local coordinates of the parent object.
		By default, sprites are positioned relatively to their top-left corner.
	**/
	public var x(get, set):Float;
	inline function get_x():Float return mX;
	inline function set_x(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mX != value)
		{
			mX = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The y coordinate relative to the local coordinates of the parent object.
		By default, sprites are positioned relatively to their top-left corner.
	**/
	public var y(get, set):Float;
	inline function get_y():Float return mY;
	inline function set_y(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mY != value)
		{
			mY = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The rotation in degrees relative to the local coordinates of the parent object.
		Positive rotation is clockwise (because the Y axis is pointing down).
	**/
	public var rotation(get, set):Float;
	inline function get_rotation():Float return mRotation;
	inline function set_rotation(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mRotation != value)
		{
			mRotation = value;
			mFlags |= HINT_ROTATE | HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The uniform scale of the object relative to its pivot point.
		Short for using scaleX & scaleY if the scaling values are equal for both axes.
	**/
	public var scale(get, set):Float;
	inline function get_scale():Float
	{
		assert(mFlags & HINT_UNIFORM_SCALE != 0, "scaling is not uniform");
		return mScaleX;
	}
	function set_scale(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mScaleX != value || mScaleY != value)
		{
			mScaleX = mScaleY = value;
			mFlags |= HINT_SCALE | HINT_UNIFORM_SCALE | HINT_LOCAL_DIRTY;
			mFlags &= ~HINT_UNIT_SCALE;
		}
		return value;
	}
	
	/**
		The horizontal scale of the object relative to its pivot point.
		The default value of 1 means no scale, values < 1 makes the sprite smaller, values > 1makes it bigger.
		To mirror a sprite along its x-axis, apply a negative scaling value.
	**/
	public var scaleX(get, set):Float;
	inline function get_scaleX():Float return mScaleX;
	function set_scaleX(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mScaleX != value)
		{
			mScaleX = value;
			mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
			mFlags |= HINT_SCALE | HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The vertical scale of the object relative to its pivot point.
		The default value of 1 means no scale, values < 1 makes the sprite smaller, values > 1makes it bigger.
		To mirror a sprite along its y-axis, apply a negative scaling value.
	**/
	public var scaleY(get, set):Float;
	inline function get_scaleY():Float return mScaleY;
	function set_scaleY(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mScaleY != value)
		{
			mScaleY = value;
			mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
			mFlags |= HINT_SCALE | HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	public var width(get, set):Float;
	function get_width():Float
	{
		return throw "override for implementation";
	}
	
	function set_width(value:Float):Float
	{
		return throw "override for implementation";
	}
	
	public var height(get, set):Float;
	function get_height():Float
	{
		return throw "override for implementation";
	}
	function set_height(value:Float):Float
	{
		return throw "override for implementation";
	}
	
	public var centerX(get, never):Float;
	inline function get_centerX():Float return x + width / 2;
	
	public var centerY(get, never):Float;
	inline function get_centerY():Float return y + height / 2;
	
	public function getSize():Sizef return new Sizef(width, height);
	
	public function getHalfSize():Sizef return new Sizef(width / 2, height / 2);
	
	public function setSize(x:Float, y:Float)
	{
		assert(Math.isFinite(x) && Math.isFinite(y));
		set_width(x);
		set_height(y);
	}
	
	/**
		The x coordinate of this object's origin in its local space. Default is 0.
		Changing the origin also changes the visual position of the sprite,
		although its x,y position remains the same.
	**/
	public var originX(get, set):Float;
	inline function get_originX():Float return mOriginX;
	function set_originX(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mOriginX != value)
		{
			mOriginX = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The y coordinate of this object's origin in its local space. Default is 0.
		Changing the origin also changes the visual position of the sprite,
		although its x,y position remains the same.
	**/
	public var originY(get, set):Float;
	inline function get_originY():Float return mOriginY;
	function set_originY(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mOriginY != value)
		{
			mOriginY = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
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
	public var pivotX(get, set):Float;
	inline function get_pivotX():Float return mPivotX;
	function set_pivotX(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mPivotX != value)
		{
			mPivotX = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		The y coordinate of this object's pivot point in its local space. Default is 0.
		The pivot point defines the object's center point for rotation and scaling.
		The coordinates of this point must be relative to the top-left corner of the sprite,
		and ignore all transformations (position, scale, rotation), e.g. the pivot point coordinates
		for the bottom-right corner would be (width, height).
	**/
	public var pivotY(get, set):Float;
	inline function get_pivotY():Float return mPivotY;
	inline function set_pivotY(value:Float):Float
	{
		assert(Math.isFinite(value));
		if (mPivotY != value)
		{
			mPivotY = value;
			mFlags |= HINT_LOCAL_DIRTY;
		}
		return value;
	}
	
	/**
		Moves the origin point to the center of this sprite.
		By default, the origin is located at the top-left corner.
	**/
	public function centerOrigin()
	{
		originX = width / 2;
		originY = height / 2;
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	/**
		Moves the pivot point from to the center of this sprite.
		By default, the pivot point is at the top-left corner.
	**/
	public function centerPivot()
	{
		throw "override for implementation";
	}
	
	inline public function setPosition(x:Float, y:Float)
	{
		assert(Math.isFinite(x) && Math.isFinite(y));
		if (mX != x || mY != y)
		{
			mX = x;
			mY = y;
			mFlags |= HINT_LOCAL_DIRTY;
		}
	}
	
	inline public function setScale(x:Float, y:Float)
	{
		assert(Math.isFinite(x) && Math.isFinite(y));
		mScaleX = x;
		mScaleY = y;
		mFlags &= ~(HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		mFlags |= HINT_SCALE | HINT_LOCAL_DIRTY;
	}
	
	public function resetOrigin()
	{
		mOriginX = mOriginY = 0;
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	public function resetPivot()
	{
		mPivotX = mPivotY = 0;
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	public function resetScale()
	{
		mScaleX = mScaleX = 1;
		mFlags &= ~HINT_SCALE;
		mFlags |= HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_LOCAL_DIRTY;
		mSpatial.local.setUnitScale2();
	}
	
	public function resetRotation()
	{
		mRotation = 0;
		mFlags &= ~HINT_ROTATE;
		mFlags |= HINT_LOCAL_DIRTY;
		mSpatial.local.setIdentityRotation();
	}
	
	public function resetTransformation()
	{
		mX = mPivotX = mOriginX = 0.;
		mY = mPivotY = mOriginY = 0.;
		mScaleX = 1.;
		mScaleY = 1.;
		mRotation = 0.;
		mFlags &= ~(HINT_ROTATE | HINT_SCALE);
		mFlags |= HINT_UNIFORM_SCALE | HINT_UNIT_SCALE | HINT_LOCAL_DIRTY;
		mSpatial.local.setIdentity2();
		
		//TODO test with spritesheet frame
		
	}

	public function getBounds(targetSpace:SpriteBase, ?output:Aabb2, ?flags:Int = 0):Aabb2
	{
		return throw "override for implementation";
	}
	
	/**
		Converts a point from local coordinates (`input`) to world space coordinates (`output`).
	**/
	public function toWorldSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		if (mFlags & HINT_LOCAL_DIRTY > 0) updateLocalTransform();
		return mSpatial.world.applyForward2(input, output);
	}
	
	/**
		Converts a point from world coordinates (`input`) to local space coordinates (`output`).
		Note: `input` and `output` can point to the same object.
	**/
	public function toLocalSpace(input:Coord2f, output:Coord2f):Coord2f
	{
		if (mFlags & HINT_LOCAL_DIRTY > 0) updateLocalTransform();
		return mSpatial.world.applyInverse2(input, output);
	}
	
	public function tick(dt:Float)
	{
		if (mSpatial.controllers != null && mSpatial.controllersEnabled)
			mSpatial.updateControllers(dt);
	}
	
	/**
		Commit changes (local transformation, alpha, visibility).
	**/
	public function syncLocal():SpriteBase
	{
		if (mFlags & (HINT_LOCAL_DIRTY | HINT_VISIBILITY_DIRTY | HINT_ALPHA_DIRTY) == 0) return this;
		
		if (mFlags & HINT_LOCAL_DIRTY > 0) updateLocalTransform();
		if (mFlags & HINT_VISIBILITY_DIRTY > 0)
		{
			if (mAlpha == 0)
				mSpatial.cullingMode = CullingMode.CullAlways; //always skip rendering
			else
				mSpatial.cullingMode = mVisible ? CullingMode.CullDynamic : CullingMode.CullAlways;
			mFlags &= ~HINT_VISIBILITY_DIRTY;
		}
		if (mFlags & HINT_ALPHA_DIRTY > 0)
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
			
			mFlags &= ~HINT_ALPHA_DIRTY;
			mSpatial.mFlags |= IS_RS_DIRTY;
		}
		return this;
	}
	
	public var tweenAni(get, never):SpriteTweenAni;
	function get_tweenAni():SpriteTweenAni
	{
		if (mTweenAni == null) mTweenAni = new SpriteTweenAni(this);
		return mTweenAni;
	}
	
	public var keyframeAni(get, never):SpriteKeyframeAni;
	function get_keyframeAni():SpriteKeyframeAni
	{
		if (mKeyframeAni == null) mKeyframeAni = new SpriteKeyframeAni(this);
		return mKeyframeAni;
	}
	
	/**
		Specifies which blend mode to use.
	**/
	public var blending(get, set):SpriteBlending;
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
	
	function updateLocalTransform()
	{
		mFlags &= ~HINT_LOCAL_DIRTY;
		mSpatial.mFlags |= IS_WORLD_XFORM_DIRTY;
		
		/*//simple brute-force SRT update
		var l = mSpatial.local;
		
		var angle = getAngle();
		var s = Math.sin(angle);
		var c = Math.cos(angle);
		var sx = mScaleX;
		var sy = mScaleY;
		sx = clampScale(sx);
		sy = clampScale(sy);
		var spx = sx * mPivotX;
		var spy = sy * mPivotY;
		
		if (sx == sy)
			l.setUniformScale2(sx);
		else
			l.setScale2(sx, sy);
		
		var m = l.getRotate();
		m.m11 = c; m.m12 =-s;
		m.m21 = s; m.m22 = c;
		l.setRotate(m);
		
		l.setTranslate2
		(
			-(spx * c) + (spy * s) + mPivotX + x - mOriginX,
			-(spx * s) - (spy * c) + mPivotY + y - mOriginY
		);*/
		
		mFlags &= ~HINT_LOCAL_DIRTY;
		mSpatial.mFlags |= IS_WORLD_XFORM_DIRTY;
		
		var l = mSpatial.local;
		
		var px = mPivotX;
		var py = mPivotY;
		
		var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
		assert(hints & (HINT_ROTATE | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE) > 0);
		if (hints & HINT_ROTATE > 0)
		{
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
					
					l.setUniformScale2(su);
					
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
					
					l.setScale2(sx, sy);
					
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
				l.setTranslate2
				(
					x - mOriginX,
					y - mOriginY
				);
			}
			else
			{
				if (hints & HINT_UNIFORM_SCALE > 0)
				{
					//R = I, S = cI
					var su = clampScale(mScaleX);
					
					l.setUniformScale2(su);
					
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
					
					l.setScale2(sx, sy);
					
					l.setTranslate2
					(
						-(sx * px) + px + x - mOriginX,
						-(sy * py) + py + y - mOriginY
					);
				}
			}
		}
	}
	
	inline public function asGroup():SpriteGroup return as(this, SpriteGroup);
	
	inline function clampScale(x:Float) return x < 0 ? (x > -SCALE_EPS ? -SCALE_EPS : x) : (x < SCALE_EPS ? SCALE_EPS : x);
	
	inline function getAngle() return Mathematics.wrap(mRotation, 360) * Mathematics.DEG_RAD;
}