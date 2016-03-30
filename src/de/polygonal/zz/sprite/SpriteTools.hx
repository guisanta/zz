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

import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.Spatial.as;

using de.polygonal.ds.tools.NativeArrayTools;

/**
	Helper methods to operate on hierarchical sprite structures.
	
	Most methods are implemented using a non-allocating, iterative traversal.
**/
@:access(de.polygonal.zz.sprite.SpriteBase)
@:access(de.polygonal.zz.scene.Spatial)
class SpriteTools
{
	static var _aSpatial = new Array<Spatial>();
	static var _aSpriteBase = new Array<SpriteBase>();
	static var _tmpCoord = new Coord2f(0, 0);
	
	static var _spatialStack = new ArrayList<Spatial>(256);
	
	/**
		Counts the total number of descendants of root.
	**/
	public static function countDescendants(root:SpriteGroup):Int
	{
		var a = _aSpatial;
		var top = 1, c = 0, s:Spatial;
		a[0] = root.mNode;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			c++;
			if (s.isNode())
			{
				s = as(s, Node).child;
				while (s != null)
				{
					a[top++] = s;
					s = s.mSibling;
				}
			}
		}
		
		return c - 1;
	}
	
	/**
		Creates an iterator over all descendants of root.
		Uses a non-allocating, iterative traversal.
	**/
	public static function descendantsIterator(root:SpriteGroup):Iterator<SpriteBase>
	{
		var a = _aSpatial;
		var top = 0, n:Node, s:Spatial, k:Int, p:Int, c:Spatial;
		
		n = root.mNode;
		k = n.numChildren;
		p = top + k;
		c = n.child;
		while (c != null)
		{
			a[p++] = c;
			c = c.mSibling;
		}
		for (i in 0...k)
		{
			a[top++] = a[--p];
			a[p] = null;
		}
		
		return
		{
			hasNext: function()
			{
				return top > 0;
			},
			next: function()
			{
				var s = a[--top];
				a[top] = null;
				
				if (s.isNode())
				{
					n = as(s, Node);
					k = n.numChildren;
					p = top + k;
					
					c = n.child;
					while (c != null)
					{
						a[p++] = c;
						c = c.mSibling;
					}
					
					for (i in 0...k)
					{
						a[top++] = a[--p];
						a[p] = null;
					}
				}
				return as(s.arbiter, SpriteBase);
			}
		}
	}
	
	/**
		Stores all descendants of `root` in `output` (or just the leafs if `leafsOnly` is true) and returns the number of elements in `output`.
	**/
	public static function descendants(root:SpriteGroup, leafsOnly:Bool, output:Array<SpriteBase>):Int
	{
		var k = 0;
		var a = _aSpatial;
		
		var top = 0;
		var s = as(root.sgn, Node).child;
		while (s != null)
		{
			a[top++] = s;
			s = s.mSibling;
		}
		
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.arbiter == null) continue;
			
			if (s.isNode())
			{
				if (!leafsOnly)
					output[k++] = s.arbiter;
				
				s = as(s, Node).child;
				while (s != null)
				{
					a[top++] = s;
					s = s.mSibling;
				}
			}
			else
				output[k++] = s.arbiter;
		}
		
		return k;
	}
	
	/**
		Calls tick() on all descendants of root, including root.
		Uses a non-allocating, iterative traversal.
	**/
	@:access(de.polygonal.zz.scene.Spatial)
	public static function tick(root:SpriteGroup, dt:Float)
	{
		var s:Spatial = root.mNode, n:Node;
		
		var a = _spatialStack;
		a.clear();
		a.pushBack(s);
		var top = 1;
		while (top != 0)
		{
			s = a.popBack();
			top--;
			
			if (s.arbiter == null) continue;
			
			if (s.controllers != null && s.controllersEnabled)
				s.updateControllers(dt);
			
			if (s.isNode())
			{
				n = as(s, Node);
				
				top += n.numChildren;
				if (top > a.capacity) a.reserve(top);
				
				var c = n.child;
				while (c != null)
				{
					a.unsafePushBack(c);
					c = c.mSibling;
				}
			}
		}
		
		a.getData().nullify(top);
	}
	
	/**
		Recursive bottom-up deconstruction: Invokes the free() method on all descendants of the given sprite.
	**/
	public static function freeSubtree(sprite:SpriteBase, includeCaller = false)
	{
		if (sprite.isGroup() && !Std.is(sprite, SpriteText))
		{
			var c = as(sprite, SpriteGroup).mNode.child, hook;
			while (c != null)
			{
				hook = c.mSibling;
				freeSubtree(as(c.arbiter, SpriteBase), true);
				c = hook;
			}
		}
		
		if (includeCaller) sprite.free();
	}
	
	public static function isAncestor(sprite:SpriteBase, target:SpriteBase):Bool
	{
		var result = false;
		var p = sprite.parent;
		while (p != null)
		{
			if (p == target)
			{
				result = true;
				break;
			}
			p = p.parent;
		}
		
		return result;
	}
	
	public static function updateWorldTransform(sprite:SpriteBase, propagateToChildren:Bool = false, updateBounds:Bool = false)
	{
		var a = _aSpatial, p = sprite.sgn, s, c = 0;
		while (p != null)
		{
			if (p.arbiter != null)
			{
				s = as(p.arbiter, SpriteBase);
				if (s.mFlags & SpriteBase.IS_LOCAL_DIRTY > 0)
					s.updateLocalTransform();
			}
			
			a[c++] = p;
			p = p.parent;
		}
		
		while (--c > -1)
		{
			a[c].updateWorldData(false, false);
			a[c] = null;
		}
		
		if (sprite.isGroup())
		{
			sprite.syncLocal(); //recursive
			
			if (propagateToChildren)
				sprite.sgn.updateGeometricState(true, updateBounds);
		}
		else
		{
			if (updateBounds) sprite.sgn.propagateBoundToRoot();
		}
	}
}