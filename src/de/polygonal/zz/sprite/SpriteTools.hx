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
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.ArrayedStack;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.scene.SpatialFlags.*;

/**
	Helper methods to operate on hierarchical sprite structures.
	
	Most methods are implemented using a non-allocating, iterative traversal.
**/
@:access(de.polygonal.zz.sprite.SpriteBase)
@:access(de.polygonal.zz.scene.Spatial)
class SpriteTools
{
	static var _tmpCoord = new Coord2f(0, 0);
	static var _spatialStack = new ArrayedStack<Spatial>();
	
	public static function gc()
	{
		_spatialStack.clear(true);
	}
	
 	/**
		Creates an iterator over all descendants of root.
		Uses a non-allocating, iterative traversal.
	**/
	public static function descendantsIterator(root:SpriteGroup, ordered:Bool = true):Iterator<SpriteBase>
	{
		var a = [], top = 0, c, i;
		
		inline function pushChildren(x:Node)
		{
			if (ordered)
			{
				c = x.child;
				i = top;
				while (c != null)
				{
					if (c.arbiter != null) a[i++] = null;
					c = c.mSibling;
				}
				c = x.child;
				while (c != null)
				{
					if (c.arbiter != null)
					{
						a[--i] = c;
						top++;
					}
					c = c.mSibling;
				}
			}
			else
			{
				c = x.child;
				while (c != null)
				{
					if (c.arbiter != null)
						a[top++] = c;
					c = c.mSibling;
				}
			}
		}
		
		pushChildren(root.mNode);
		
		return
		{
			hasNext: function()
			{
				return top > 0;
			},
			next: function()
			{
				var s = a[--top];
				if (s.isNode() && s.mFlags & SKIP_CHILDREN == 0)
					pushChildren(as(s, Node));
				return s.arbiter;
			}
		}
	}
	
	/**
		Stores all descendants of `root` in `output` (or just the leafs if `leafsOnly` is true) and returns the number of elements in `output`.
		@param ordered if true, sprite objects are stored in the correct draw order.
	**/
	public static function descendants(root:SpriteGroup, leafsOnly:Bool, ordered:Bool = false, output:ArrayList<SpriteBase>)
	{
		var stack = _spatialStack;
		stack.clear();
		stack.push(root.sgn);
		var spatial, sprite, n, c, i;
		while (stack.size > 0)
		{
			spatial = stack.pop();
			
			if (ordered)
			{
				if (spatial.isNode())
				{
					n = as(spatial, Node);
					i = stack.size + n.numChildren;
					for (i in 0...n.numChildren) stack.push(null);
					c = n.child;
					while (c != null)
					{
						stack.set(--i, c);
						c = c.mSibling;
					}
				}
			}
			else
			{
				if (spatial.isNode() && spatial.mFlags & SKIP_CHILDREN == 0)
				{
					n = as(spatial, Node);
					c = n.child;
					while (c != null)
					{
						stack.push(c);
						c = c.mSibling;
					}
				}
			}
			
			sprite = as(spatial.arbiter, SpriteBase);
			if (sprite == null) continue;
			if (leafsOnly && sprite.type == SpriteGroup.TYPE) continue;
			output.pushBack(sprite);
		}
	}
	
	/**
		Calls tick() on all descendants of root, including root.
		Uses a non-allocating, iterative traversal.
	**/
	@:access(de.polygonal.zz.scene.Spatial)
	public static function tick(root:SpriteGroup, dt:Float)
	{
		var stack = _spatialStack, s, n, c;
		stack.clear();
		stack.push(root.mNode);
		while (stack.size > 0)
		{
			s = stack.pop();
			
			if (s.arbiter == null) continue;
			
			if (s.controllers != null && s.controllersEnabled)
				s.updateControllers(dt);
			
			//SKIP_CHILDREN: SpriteText glyph nodes have no arbiter so don't bother iterating over them
			if (s.mFlags & (IS_NODE | SKIP_CHILDREN) == IS_NODE)
			{
				n = as(s, Node);
				c = n.child;
				while (c != null)
				{
					stack.push(c);
					c = c.mSibling;
				}
			}
		}
	}
	
	/**
		Recursive bottom-up deconstruction: Invokes free() method on all descendants of the given sprite.
	**/
	public static function freeSubtree(sprite:SpriteBase, includeCaller = false)
	{
		if (sprite.type == SpriteGroup.TYPE)
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
	
	/**
		Returns true if `sprite` is an ancestor of `target`.
	**/
	public static function isAncestor(sprite:SpriteBase, target:SpriteBase):Bool
	{
		var p = sprite.parent;
		while (p != null)
		{
			if (p == target)
				return true;
			p = p.parent;
		}
		return false;
	}
	
	public static function updateWorldTransform(sprite:SpriteBase, propagateToChildren:Bool = false, updateBounds:Bool = false)
	{
		var stack = _spatialStack, p = sprite.sgn, s;
		while (p != null)
		{
			if (p.arbiter != null)
			{
				s = as(p.arbiter, SpriteBase);
				if (s.mFlags & SpriteBase.IS_LOCAL_DIRTY > 0)
					s.updateLocalTransform();
			}
			
			stack.push(p);
			p = p.parent;
		}
		
		while (stack.size > 0)
			stack.pop().updateWorldData(false, false);
		
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
	
	public static function fitBounds(sprite:SpriteBase, bounds:Aabb2)
	{
		if (sprite.isGroup())
		{
			var g = sprite.asGroup();
			var b = g.getLocalBounds();
			var size = g.getSize();
			g.scale = M.fmin(bounds.w / size.x, bounds.h / size.y);
			g.x = bounds.x;
			g.y = bounds.y;
		}
		else
		{
			sprite.x = bounds.x;
			sprite.y = bounds.y;
			sprite.scale = 1;
			sprite.scale = M.fmin(bounds.w / sprite.width, bounds.h / sprite.height);
		}
	}
}