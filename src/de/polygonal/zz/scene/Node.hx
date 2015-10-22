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

Geometric Tools, LLC
Copyright (c) 1998-2012
Distributed under the Boost Software License, Version 1.0.
http://www.boost.org/LICENSE_1_0.txt
http://www.geometrictools.com/License/Boost/LICENSE_1_0.txt
*/
package de.polygonal.zz.scene;

import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Coord2;
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.scene.Bv.BvType;
import de.polygonal.zz.scene.GlobalStateStack.GlobalStateStackList;
import de.polygonal.zz.scene.Spatial.as;

/**
	Allows grouping of child nodes.
**/
class Node extends Spatial
{
	public static var getBvTypeFunc:Void->BvType = null;
	
	/**
		The first child of this node.
	**/
	public var child(default, null):Spatial;
	
	public var numChildren(default, null):Int;
	
	public function new(?name:String)
	{
		super(name);
		mFlags |= Spatial.IS_NODE;
		child = null;
		numChildren = 0;
	}
	
	override public function free()
	{
		super.free();
		child = null;
	}
	
	override function getVisibleSet(culler:Culler, noCull:Bool)
	{
		var n = child;
		while (n != null)
		{
			n.onGetVisibleSet(culler, noCull);
			n = n.mSibling;
		}
	}
	
	override public function getBoundingBox(targetSpace:Spatial, output:Aabb2):Aabb2
	{
		return TreeUtil.getBoundingBox(this, targetSpace, output);
	}
	
	override public function pick(point:Coord2f, ?result:PickResult):Int
	{
		var c = 0;
		if (worldBound.contains(point))
		{
			var n = child;
			while (n != null)
			{
				c += n.pick(point, result);
				n = n.mSibling;
			}
		}
		return c;
	}
	
	//{ child management
	
	public function addChild(x:Spatial):Node
	{
		assert(x != null);
		assert(x != this);
		assert(x.parent == null);
		
		if (child == null)
		{
			child = x;
			x.mSibling = null;
		}
		else
		{
			//find last child
			var c = child;
			while (c.mSibling != null) c = c.mSibling;
			c.mSibling = x;
		}
		
		x.parent = this;
		numChildren++;
		return this;
	}
	
	public function addChildAt(x:Spatial, index:Int):Node
	{
		assert(x != null);
		assert(x != this);
		assert(x.parent == null);
		assert(index <= numChildren);
		
		if (index == 0)
		{
			x.mSibling = child;
			child = x;
		}
		else
		{
			var c = child;
			for (i in 0...index - 1) c = c.mSibling;
			x.mSibling = c.mSibling;
			c.mSibling = x;
		}
		
		x.parent = this;
		numChildren++;
		return this;
	}
	
	public function removeChild(x:Spatial):Node
	{
		assert(x != null);
		assert(x != this);
		assert(x.parent == this);
		
		if (child == x)
		{
			child = x.mSibling;
			x.mSibling = null;
		}
		else
		{
			//find predecessor to x
			var c = child;
			while (c.mSibling != x) c = c.mSibling;
			c.mSibling = x.mSibling;
			x.mSibling = null;
		}
		
		x.parent = null;
		numChildren--;
		return this;
	}
	
	public function removeChildAt(index:Int):Node
	{
		assert(index < numChildren);
		
		var x;
		if (index == 0)
		{
			x = child;
			child = child.mSibling;
			x.mSibling = null;
		}
		else
		{
			var c = child;
			for (i in 0...index - 1) c = c.mSibling;
			x = c.mSibling;
			c.mSibling = x.mSibling;
			x.mSibling = null;
		}
		
		x.parent = this;
		numChildren--;
		return this;
	}
	
	/**
		Removes all children in the interval [`beginIndex`, `endIndex`&rsqb;.
		
		If `beginIndex` and `endIndex` are omited, all children get removed.
		If `endIndex` is omited, all children in the interval [`beginIndex`, `numChildren`) get removed.
	**/
	public function removeChildren(beginIndex = 0, endIndex = -1):Node
	{
		if (beginIndex == 0 && endIndex == -1)
		{
			var e = child;
			while (e != null)
			{
				var t = e.mSibling;
				e.parent = null;
				e.mSibling = null;
				e = t;
			}
			child = null;
			numChildren = 0;
		}
		else
		{
			if (endIndex == -1) endIndex = numChildren - 1;
			
			assert(beginIndex >= 0);
			assert(endIndex >= beginIndex);
			
			if (beginIndex == 0)
			{
				var i = 0;
				var c = child;
				while (i < endIndex)
				{
					var hook = c.mSibling;
					c.mSibling = null;
					c.parent = null;
					c = hook;
					i++;
				}
				child = c.mSibling;
			}
			else
			{
				var a = child;
				var i = 0;
				while (i < beginIndex - 1)
				{
					a = a.mSibling;
					i++;
				}
				
				var t = a;
				var b = a.mSibling;
				i++;
				while (i <= endIndex)
				{
					var hook = b.mSibling;
					b.mSibling = null;
					b.parent = null;
					b = hook;
					i++;
				}
				t.mSibling = b;
			}
			
			numChildren -= (endIndex - beginIndex) + 1;
		}
		return this;
	}
	
	public function getChildAt(index:Int):Spatial
	{
		assert(index >= 0 && index < numChildren, "index=" + index);
		
		var e = child;
		var i = 0;
		while (i <= index)
		{
			if (i == index) return e;
			e = e.mSibling;
			i++;
		}
		return null;
	}
	
	public function getChildIndex(x:Spatial):Int
	{
		assert(x != null);
		assert(x.parent == this);
		
		var e = child;
		var i = 0;
		while (e != null)
		{
			if (e == x) return i;
			e = e.mSibling;
			i++;
		}
		return -1;
	}
	
	public function setChildIndex(x:Spatial, index:Int):Node
	{
		assert(x != null);
		assert(x.parent == this);
		assert(index >= 0 && index < numChildren);
		
		removeChild(x);
		addChildAt(x, index);
		return this;
	}
	
	public function getChildByName(name:String):Spatial
	{
		var e = child;
		while (e != null)
		{
			if (e.name == name)
				return e;
			e = e.mSibling;
		}
		return null;
	}
	
	public function getDescendants(output:Array<Spatial>):Array<Spatial>
	{
		var e = child;
		while (e != null)
		{
			output.push(e);
			if (e.isNode())
				as(e, Node).getDescendants(output);
			e = e.mSibling;
		}
		return output;
	}
	
	public function getDescendantByName(name:String):Spatial
	{
		var e = child, s:String, t;
		while (e != null)
		{
			if (e.name == name) return e;
			if (e.isNode())
			{
				t = as(e, Node).getDescendantByName(name);
				if (t != null) return t;
			}
			e = e.mSibling;
		}
		return null;
	}
	
	public function getAllDescendantsByName(name:String, output:Array<Spatial>):Array<Spatial>
	{
		var e = child, s:String;
		while (e != null)
		{
			if (e.name == name) output.push(e);
			if (e.isNode())
				as(e, Node).getAllDescendantsByName(name, output);
			e = e.mSibling;
		}
		return output;
	}
	
	public function swapChildren(x:Spatial, y:Spatial):Node
	{
		assert(x != null && y != null);
		assert(x.parent == this && y.parent == this);
		assert(x != y);
		assert(numChildren > 1);
		
		var x0 = null;
		var y0 = null;
		var i = 0;
		var e = child;
		while (i < 2 && e != null)
		{
			if (e.mSibling == x)
			{
				x0 = e;
				i++;
			}
			else
			if (e.mSibling == y)
			{
				y0 = e;
				i++;
			}
			e = e.mSibling;
		}
		
		var x1 = x.mSibling;
		var y1 = y.mSibling;
		x.mSibling = null;
		y.mSibling = null;
		
		if (x1 == y) //adjacent x,y
		{
			if (x0 != null)
				x0.mSibling = y;
			else
				child = y;
			y.mSibling = x;
			x.mSibling = y1;
		}
		else
		if (y1 == x) //adjacent y,x
		{
			if (y0 != null)
				y0.mSibling = x;
			else
				child = x;
			x.mSibling = y;
			y.mSibling = x1;
		}
		else
		{
			if (x0 != null)
			{
				x0.mSibling = y;
				y.mSibling = x1;
			}
			else
			{
				child = y;
				y.mSibling = x1;
			}
			
			if (y0 != null)
			{
				y0.mSibling = x;
				x.mSibling = y1;
			}
			else
			{
				child = x;
				x.mSibling = y1;
			}
		}
		return this;
	}
	
	public function swapChildrenAt(i:Int, j:Int):Node
	{
		swapChildren(getChildAt(i), getChildAt(j));
		return this;
	}
	
	public function setFirst(x:Spatial):Node
	{
		assert(x != null);
		assert(x.parent == this);
		
		if (child == x) return this;
		var c = child;
		while (c.mSibling != x) c = c.mSibling;
		c.mSibling = x.mSibling;
		x.mSibling = child;
		child = x;
		return this;
	}
	
	public function setLast(x:Spatial):Node
	{
		assert(x != null);
		assert(x.parent == this);
		
		if (x.mSibling == null) return this;
		var c = child;
		if (c == x)
		{
			while (c.mSibling != null) c = c.mSibling;
			c.mSibling = x;
			child = x.mSibling;
		}
		else
		{
			while (c.mSibling != x) c = c.mSibling;
			c = c.mSibling = x.mSibling;
			while (c.mSibling != null) c = c.mSibling;
			c.mSibling = x;
		}
		x.mSibling = null;
		return this;
	}
	
	/**
		Iterates over all children.
	**/
	public function iterator():Iterator<Spatial>
	{
		var e = child;
		return
		{
			hasNext: function()
			{
				return e != null;
			},
			next: function()
			{
				var t = e;
				e = e.mSibling;
				return t;
			}
		}
	}
	
	//}
	
	override function updateWorldData(updateBound:Bool)
	{
		super.updateWorldData(updateBound);
		
		//downward pass: propagate geometric update to children
		var n = child;
		while (n != null)
		{
			n.updateGeometricState(false, updateBound);
			n = n.mSibling;
		}
	}
	
	override function updateWorldBound()
	{
		if (!worldBoundCurrent)
		{
			#if profile
			SceneStats.numBvUpdates++;
			#end
			
			//compute world bounding volume containing world bounding volume of all its children
			//set to first non-null child
			if (child == null) return;
			
			//merge world bound with the world bounds of all children
			var c = child;
			worldBound.of(c.worldBound);
			c = c.mSibling;
			while (c != null)
			{
				worldBound.growToContain(c.worldBound);
				c = c.mSibling;
			}
			
			mFlags &= ~Spatial.IS_WORLD_BOUND_DIRTY;
		}
	}
	
	override function propagateRenderStateUpdate(stack:GlobalStateStackList)
	{
		//downward pass: propagate render state update to children
		var n = child;
		while (n != null)
		{
			n.updateRenderState(stack);
			n = n.mSibling;
		}
	}
	
	override function getBvType():BvType
	{
		if (getBvTypeFunc != null) return getBvTypeFunc();
		return super.getBvType();
	}
}