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
import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.PickResult;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.TreeUtil;
import de.polygonal.zz.sprite.SpriteBase.*;
import de.polygonal.zz.sprite.SpriteUtil;
import haxe.ds.Vector;
import de.polygonal.zz.scene.Spatial.as;

/**
	A 'container' node that does not a have size in itself.
	The width and height properties represent the extents of its children.
	Changing those properties will scale all children accordingly.
**/
@:build(de.polygonal.core.macro.IntConsts.build([IS_TOPOLOGY_FLATTENED], true, false, "de.polygonal.zz.sprite.SpriteBase"))
@:access(de.polygonal.zz.scene.Spatial)
class SpriteGroup extends SpriteBase
{
	var mNode:Node;
	var mDescendants:Vector<SpriteBase>;
	var mBoundOut:Aabb2;
	
	var mResult:PickResult;
	
	public function new(?name:String, ?parent:SpriteGroup, ?children:Array<SpriteBase>)
	{
		super(new Node(name));
		mNode = cast(mSpatial, Node);
		if (parent != null) parent.addChild(this);
		if (children != null)
			for (i in children)
				addChild(i);
		mBoundOut = new Aabb2();
	}
	
	public function flatten()
	{
		mDescendants = new Vector<SpriteBase>(SpriteUtil.count(this));
		var i = 0;
		for (j in SpriteUtil.descendants(this)) mDescendants.set(i, j);
		mFlags |= IS_TOPOLOGY_FLATTENED;
	}
	
	public function unflatten()
	{
		mDescendants = null;
		mFlags &= ~IS_TOPOLOGY_FLATTENED;
	}
	
	override public function commit()
	{
		if (getDirty())
		{
			clrDirty();
			
			invalidateWorldTransform();
			
			updateAlphaAndVisibility();
			
			//same as Sprite.update() but ignores (mSizeX, mSizeY)
			
			var l = mSpatial.local;
			
			var px = mPivotX;
			var py = mPivotY;
			
			var hints = mFlags & (HINT_ROTATE | HINT_SCALE | HINT_UNIFORM_SCALE | HINT_UNIT_SCALE);
			assert(hints & (HINT_ROTATE | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE) > 0);
			if (hints & HINT_ROTATE > 0)
			{
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
						
						l.setUniformScale2(su);
						
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
						
						l.setScale2(sx, sy);
						
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
					l.setTranslate2
					(
						x + mOriginX,
						y + mOriginY
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
							-(su * px) + px + x + mOriginX,
							-(su * py) + py + y + mOriginY
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
							-(sx * px) + px + x + mOriginX,
							-(sy * py) + py + y + mOriginY
						);
					}
				}
			}
		}
		
		//update descendants
		if (isFlattened())
		{
			//iterative
			for (c in mDescendants)
				if (c.getDirty())
					c.commit();
		}
		else
		{
			//recursive
			var c = mNode.child;
			while (c != null)
			{
				as(c.arbiter, SpriteBase).commit();
				c = c.mSibling;
			}
		}
	}
	
	override public function free()
	{
		assert(numChildren == 0, "children must be removed first before calling free()");
		mNode = null;
		super.free();
	}
	
	public function freeDescendants()
	{
		SpriteUtil.freeSubtree(this);
		mFlags &= ~IS_TOPOLOGY_FLATTENED;
		mDescendants = null;
	}
	
	//{ child management
	
	public var numChildren(get_numChildren, never):Int;
	inline function get_numChildren():Int return mNode.numChildren;
	
	public function addChild(child:SpriteBase):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.addChild(child.mSpatial);
		return this;
	}

	public function addChildAt(x:SpriteBase, index:Int):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.addChildAt(x.mSpatial, index);
		return this;
	}
		
	public function removeChild(x:SpriteBase):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.removeChild(x.mSpatial);
		return this;
	}

	public function removeChildAt(index:Int):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.removeChildAt(index);
		return this;
	}

	public function removeChildren(beginIndex = 0, endIndex = -1):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.removeChildren(beginIndex, endIndex);
		return this;
	}

	public function getChildAt(index:Int):SpriteBase
	{
		return as(mNode.getChildAt(index).arbiter, SpriteBase);
	}

	public function getChildIndex(x:SpriteBase):Int
	{
		return mNode.getChildIndex(x.mSpatial);
	}

	public function setChildIndex(x:SpriteBase, index:Int):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.setChildIndex(x.mSpatial, index);
		return this;
	}

	public function getChildByName(name:String):SpriteBase
	{
		var child = mNode.getChildByName(name);
		if (child == null) return null;
		return as(child.arbiter, SpriteBase);
	}
	
	public function getDescendantByName(name:String):SpriteBase
	{
		var descendant = mNode.getDescendantByName(name);
		if (descendant == null) return null;
		return as(SpriteBase, descendant.arbiter);
	}

	public function getAllDescendantsByName(name:String, output:Array<SpriteBase>):Array<SpriteBase>
	{
		var a = mNode.getAllDescendantsByName(name, []);
		for (i in 0...a.length)
			output[i] = as(a[i].arbiter, SpriteBase);
		return output;
	}
	
	public function swapChildren(x:SpriteBase, y:SpriteBase):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.swapChildren(x.mSpatial, y.mSpatial);
		return this;
	}

	public function swapChildrenAt(i:Int, j:Int):SpriteGroup
	{
		assert(!isFlattened(), "group must not be flattened.");
		mNode.swapChildrenAt(i, j);
		return this;
	}
	
	public function getChildren(output:Vector<SpriteBase>):Vector<SpriteBase>
	{
		var c = mNode.child;
		for (i in 0...mNode.numChildren)
		{
			output[i] = as(c.arbiter, SpriteBase);
			c = c.mSibling;
		}
		return output;
	}
	
	public function sendToForeground(?x:SpriteBase):SpriteGroup
	{
		if (x == null)
		{
			if (parent != null)
				mNode.parent.setLast(mSpatial);
			return this;
		}
		
		assert(!isFlattened(), "group must not be flattened.");
		mNode.setLast(x.mSpatial);
		return this;
	}

	public function sentToBackground(?x:SpriteBase):SpriteGroup
	{
		if (x == null)
		{
			if (parent != null)
				mNode.parent.setFirst(mSpatial);
			return this;
		}
		
		assert(!isFlattened(), "group must not be flattened.");
		mNode.setFirst(x.mSpatial);
		return this;
	}
	
	public function iterator():Iterator<SpriteBase>
	{
		var e = mNode.child;
		return
		{
			hasNext: function()
			{
				return e != null;
			},
			next: function()
			{
				var t = as(e.arbiter, SpriteBase);
				e = e.mSibling;
				return t;
			}
		}
	}
	
	//}
	
	public function pick(point:Coord2f, result:Array<Sprite>):Int
	{
		if (getDirty()) commit();
		
		var f = sgn.mFlags;
		if (f & Spatial.IS_WORLD_XFORM_DIRTY > 0)
			sgn.updateGeometricState(false, true);
		else
		if (f & Spatial.IS_WORLD_BOUND_DIRTY > 0)
			sgn.updateBoundState(true, false);
		
		if (mResult == null) mResult = new PickResult();	
		var k = mNode.pick(point, mResult);
		for (i in 0...k) result[i] = as(mResult.get(i).arbiter, Sprite);
		return k;
	}
	
	override public function getBounds(targetSpace:SpriteBase, output:Aabb2):Aabb2
	{
		var r = getRoot();
		r.commit();
		TreeUtil.updateGeometricState(as(r.sgn, Node), true);
		
		return mSpatial.getBoundingBox(targetSpace.sgn, output);
	}
	
	override function get_width():Float
	{
		return getBounds(this, mBoundOut).w;
	}
	override function set_width(value:Float):Float
	{
		var w = get_width();
		scaleX = value / w;
		return value;
	}
	
	override function get_height():Float
	{
		return getBounds(this, mBoundOut).h;
	}
	override function set_height(value:Float):Float
	{
		var h = get_height();
		scaleY = value / h;
		return value;
	}
	
	/**
		Takes only into account existing sprites.
		If sprites are added or removed, this method has to be called every time a sprite is added or removed.
	**/
	override public function centerPivot()
	{
		commit();
		mNode.updateGeometricState();
		
		var bound = getBounds(this, mBoundOut);
		mPivotX = bound.w / 2;
		mPivotY = bound.h / 2;
		setDirty();
	}
	
	override public function centerOrigin()
	{
		var bound = getBounds(this, mBoundOut);
		originX = -bound.w / 2;
		originY = -bound.h / 2;
		setDirty();
	}
	
	override public function centerPivotAndOrigin()
	{
		var bound = getBounds(this, mBoundOut);
		var cx = bound.w / 2;
		var cy = bound.h / 2;
		mPivotX = cx;
		mPivotY = cy;
		originX =-cx;
		originY =-cy;
		setDirty();
	}
	
	inline function isFlattened() return mFlags & IS_TOPOLOGY_FLATTENED > 0;
}