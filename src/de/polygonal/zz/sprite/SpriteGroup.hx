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
import de.polygonal.core.math.Limits;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.PickResult;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.scene.TreeTools;
import de.polygonal.zz.sprite.SpriteBase.*;
import de.polygonal.zz.sprite.Sprite.*;
import de.polygonal.zz.sprite.SpriteTools;
import de.polygonal.core.math.Mathematics;

/**
	A 'container' node that does not a have size in itself.
	The width and height properties represent the extents of its children.
	Changing those properties will scale all children accordingly.
**/
@:access(de.polygonal.zz.scene.Spatial)
class SpriteGroup extends SpriteBase
{
	inline public static var TYPE = 2;
	
	var mNode:Node;
	var mBoundOut:Aabb2;
	var mResult:PickResult;
	
	public function new(?name:String, ?parent:SpriteGroup, ?children:Array<SpriteBase>)
	{
		super(new Node(name));
		
		type = TYPE;
		
		mNode = cast(mSpatial, Node);
		if (parent != null) parent.addChild(this);
		if (children != null)
			for (i in children)
				addChild(i);
		mBoundOut = new Aabb2();
	}
	
	override public function syncLocal():SpriteBase
	{
		super.syncLocal();
		
		var c = mNode.child, s;
		while (c != null)
		{
			s = as(c.arbiter, SpriteBase);
			if (s.isGroup())
			{
				s.syncLocal();
				c = c.mSibling;
				continue;
			}
			
			s.syncLocal();
			c = c.mSibling;
		}
		return this;
	}
	
	override public function free()
	{
		assert(numChildren == 0, "children must be removed first before calling free()");
		mNode = null;
		
		super.free();
	}
	
	public function freeDescendants()
	{
		SpriteTools.freeSubtree(this);
	}
	
	//{ child management
	
	public var numChildren(get, never):Int;
	inline function get_numChildren():Int return mNode.numChildren;
	
	public function addChild(child:SpriteBase):SpriteGroup
	{
		mNode.addChild(child.mSpatial);
		return this;
	}
	
	public function addChildAt(x:SpriteBase, index:Int):SpriteGroup
	{
		mNode.addChildAt(x.mSpatial, index);
		return this;
	}
	
	public function removeChild(x:SpriteBase):SpriteGroup
	{
		mNode.removeChild(x.mSpatial);
		return this;
	}
	
	public function removeChildAt(index:Int):SpriteGroup
	{
		mNode.removeChildAt(index);
		return this;
	}
	
	public function removeChildren(beginIndex = 0, endIndex = -1):SpriteGroup
	{
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
			output[i] = as(a[i].mArbiter, SpriteBase);
		return output;
	}
	
	public function swapChildren(x:SpriteBase, y:SpriteBase):SpriteGroup
	{
		mNode.swapChildren(x.mSpatial, y.mSpatial);
		return this;
	}
	
	public function swapChildrenAt(i:Int, j:Int):SpriteGroup
	{
		mNode.swapChildrenAt(i, j);
		return this;
	}
	
	public function getChildren(output:Array<SpriteBase>):Array<SpriteBase>
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
		if (mFlags & IS_LOCAL_DIRTY > 0) syncLocal();
		
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
	
	override public function tick(dt:Float)
	{
		super.tick(dt);
		
		var c = mNode.child, s, hook;
		while (c != null)
		{
			hook = c.mSibling; //in case controller removes the spatial
			s = as(c.arbiter, SpriteBase);
			s.tick(dt);
			c = hook;
		}
	}
	
	public function getLocalBounds():Aabb2
	{
		TreeTools.updateGeometricState(as(mSpatial, Node), false);
		return mSpatial.getBoundingBox(mSpatial, mBoundOut);
	}
	
	public function getWorldBounds():Aabb2
	{
		var r = getRoot();
		r.syncLocal();
		var n = as(r.sgn.getRoot(), Node);
		TreeTools.updateGeometricState(n, true);
		return mSpatial.getBoundingBox(n, mBoundOut);
	}
	
	@:access(de.polygonal.zz.sprite.Sprite)
	override public function getBounds(targetSpace:SpriteBase, ?output:Aabb2, ?flags:Int = 0):Aabb2
	{
		if (output == null) output = new Aabb2();
		
		var leafs = null, k = 0, i = 0;
		
		var untrim = flags & Sprite.FLAG_TRIM == 0;
		if (untrim)
		{
			leafs = [];
			k = SpriteTools.descendants(this, true, leafs);
			var s;
			while (i < k)
			{
				s = leafs[i];
				if (s.type == Sprite.TYPE && s.mFlags & HINT_TRIMMED > 0)
				{
					as(s, Sprite).undoTrim();
					i++;
				}
				else
				{
					k--;
					leafs[i] = leafs[k];
					leafs[k] = null;
				}
			}
		}
		
		SpriteTools.updateWorldTransform(this, true);
		if (SpriteTools.isAncestor(this, targetSpace) == false)
			SpriteTools.updateWorldTransform(targetSpace);
		
		var minX = Limits.FLOAT_MAX;
		var minY = Limits.FLOAT_MAX;
		var maxX = Limits.FLOAT_MIN;
		var maxY = Limits.FLOAT_MIN;
		
		var c = new Coord2f();
		var b = new Aabb2();
		
		var a = [sgn], top = 1, s, n, c, arbiter;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			arbiter = as(s.arbiter, SpriteBase);
			if (arbiter == null) continue;
			
			if (s.isNode())
			{
				n = as(s, Node);
				c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
			else
			{
				arbiter.getBounds(targetSpace, b, flags | Sprite.FLAG_SKIP_UNTRIM | Sprite.FLAG_SKIP_WORLD_UPDATE);
				
				if (b.minX < minX) minX = b.minX;
				if (b.minY < minY) minY = b.minY;
				if (b.maxX > maxX) maxX = b.maxX;
				if (b.maxY > maxY) maxY = b.maxY;
			}
		}
		
		output.minX = minX;
		output.minY = minY;
		output.maxX = maxX;
		output.maxY = maxY;
		
		if (untrim)
		{
			while (--k > -1)
			{
				as(leafs[k], Sprite).redoTrim();
				leafs[k] = null;
			}
		}
		return output;
	}
	
	override public function getSize():Sizef
	{
		getBounds(parent, mBoundOut);
		return new Sizef(mBoundOut.w, mBoundOut.h);
	}
	
	override public function setSize(x:Float, y:Float)
	{
		return throw "unsupported operation (a SpriteGroup object only supports uniform scaling)";
	}
	
	override function get_width():Float
	{
		return getBounds(parent, mBoundOut).w;
	}
	override function set_width(value:Float):Float
	{
		return throw "unsupported operation (a SpriteGroup object only supports uniform scaling)";
	}
	
	override function get_height():Float
	{
		return getBounds(parent, mBoundOut).h;
	}
	override function set_height(value:Float):Float
	{
		return throw "unsupported operation (a SpriteGroup object only supports uniform scaling)";
	}
	
	override function set_scaleX(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteGroup object only supports uniform scaling.");
		
		return value;
	}
	override function set_scaleY(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteGroup object only supports uniform scaling.");
		
		return value;
	}
	
	/**
		Takes only into account existing sprites.
		
		This method has to be called every time a sprite is added or removed.
	**/
	override public function centerPivot()
	{
		if (mFlags & IS_LOCAL_DIRTY > 0) syncLocal();
		
		mNode.updateGeometricState();
		
		var bound = getBounds(this, mBoundOut);
		mPivotX = bound.w / 2;
		mPivotY = bound.h / 2;
		
		mFlags |= IS_LOCAL_DIRTY;
	}
	
	override public function centerOrigin()
	{
		var bound = getBounds(this, mBoundOut);
		originX = -bound.w / 2;
		originY = -bound.h / 2;
		mFlags |= IS_LOCAL_DIRTY;
	}
}